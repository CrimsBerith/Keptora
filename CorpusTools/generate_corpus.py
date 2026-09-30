#!/usr/bin/env python3
"""Deterministic Keptora corpus generator for exact and visual grouping tests."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps
import argparse, json, random, shutil, subprocess

RELATIONS = ("exact", "recompressed", "resized", "rotated", "cropped", "watermarked", "color_edit", "metadata_copy")

def save_jpeg(img, path, quality=92, comment=None):
    kwargs = {"quality": quality, "optimize": False}
    if comment is not None: kwargs["comment"] = comment.encode("utf-8")
    img.save(path, **kwargs)

def make_original(index, rng):
    w, h = (960, 640) if index % 2 == 0 else (640, 960)
    base = Image.new("RGB", (w, h), (rng.randrange(25, 220), rng.randrange(25, 220), rng.randrange(25, 220)))
    draw = ImageDraw.Draw(base)
    for n in range(12):
        x0, y0 = rng.randrange(w), rng.randrange(h)
        x1, y1 = min(w, x0 + rng.randrange(20, 240)), min(h, y0 + rng.randrange(20, 180))
        draw.rounded_rectangle((x0, y0, x1, y1), radius=12, outline=(255,255,255), width=3)
    draw.text((24, 24), f"Keptora asset {index}", fill="white")
    return base

def create_variant(kind, img, base_path, target, index):
    if kind == "exact": shutil.copy2(base_path, target)
    elif kind == "recompressed": save_jpeg(img, target, quality=58)
    elif kind == "resized": save_jpeg(img.resize((max(64, img.width//2), max(64, img.height//2))), target, quality=88)
    elif kind == "rotated": save_jpeg(img.rotate(3, resample=Image.Resampling.BICUBIC, expand=False), target, quality=90)
    elif kind == "cropped":
        margin = max(8, min(img.size)//12)
        crop = img.crop((margin, margin, img.width-margin, img.height-margin)).resize(img.size)
        save_jpeg(crop, target, quality=90)
    elif kind == "watermarked":
        copy = img.copy(); draw = ImageDraw.Draw(copy)
        draw.rounded_rectangle((20, img.height-88, 270, img.height-20), radius=14, fill=(0,0,0,150))
        draw.text((38, img.height-67), "CULLORA TEST", fill="white")
        save_jpeg(copy, target, quality=90)
    elif kind == "color_edit": save_jpeg(ImageEnhance.Color(img).enhance(0.55), target, quality=90)
    elif kind == "metadata_copy": save_jpeg(img, target, quality=92, comment=f"metadata-{index}")

def add_raw_family(out, family_index, truth):
    stem = f"raw_family_{family_index:05d}"
    raw = out / f"{stem}.dng"; raw.write_bytes(b"CULLORA_SYNTHETIC_RAW_PLACEHOLDER\0" + bytes(str(family_index), "utf-8"))
    xmp = out / f"{stem}.xmp"; xmp.write_text(f"<x:xmpmeta><rdf:Description keptora:id='{family_index}'/></x:xmpmeta>")
    preview = Image.new("RGB", (480, 320), (60, 74, 92)); ImageDraw.Draw(preview).text((20,20), stem, fill="white")
    jpg = out / f"{stem}.jpg"; save_jpeg(preview, jpg)
    for path, role in ((raw,"raw"),(xmp,"sidecar"),(jpg,"jpeg_preview")):
        truth.append({"path":path.name,"family_id":stem,"relation":role,"expected_exact_group":None,"expected_visual_group":stem,"forbidden_merge_group":None})


def add_burst_fixture(out, index, truth, members=4):
    stem=f"burst_{index:05d}"
    for member in range(1, members+1):
        name=f"{stem}_BURST{member:03d}.jpg"
        image=Image.new("RGB",(640,480),(72+member*8,82,112))
        ImageDraw.Draw(image).text((20,20),name,fill="white")
        path=out/name; save_jpeg(image,path)
        truth.append({"path":path.name,"family_id":stem,"relation":"burst_member","expected_exact_group":None,"expected_visual_group":stem,"forbidden_merge_group":None})

def add_live_photo_fixture(out, index, truth):
    stem=f"live_{index:05d}"
    image=Image.new("RGB",(640,480),(36,96,110)); ImageDraw.Draw(image).text((20,20),stem,fill="white")
    jpg=out/f"{stem}.jpg"; save_jpeg(image,jpg)
    mov=out/f"{stem}.mov"
    ffmpeg=shutil.which("ffmpeg")
    if ffmpeg:
        subprocess.run([ffmpeg,"-loglevel","error","-y","-loop","1","-i",str(jpg),"-t","1","-vf","format=yuv420p","-c:v","libx264",str(mov)],check=False)
    if not mov.exists(): mov.write_bytes(b"CULLORA_SYNTHETIC_LIVE_PHOTO_VIDEO")
    for path,role in ((jpg,"live_photo_image"),(mov,"live_photo_video")):
        truth.append({"path":path.name,"family_id":stem,"relation":role,"expected_exact_group":None,"expected_visual_group":stem,"forbidden_merge_group":None})

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--out",required=True)
    parser.add_argument("--count",type=int,default=1000)
    parser.add_argument("--seed",type=int,default=42)
    parser.add_argument("--raw-families",type=int,default=4)
    parser.add_argument("--live-pairs",type=int,default=2)
    parser.add_argument("--burst-families",type=int,default=2)
    args=parser.parse_args()
    out=Path(args.out); out.mkdir(parents=True,exist_ok=True)
    rng=random.Random(args.seed); truth=[]
    originals=max(1,args.count//(len(RELATIONS)+1))
    for i in range(originals):
        img=make_original(i,rng); base=out/f"{i:06d}_original.jpg"; save_jpeg(img,base,quality=95)
        family=f"visual-{i:06d}"; exact=f"exact-{i:06d}"
        truth.append({"path":base.name,"family_id":family,"relation":"original","expected_exact_group":exact,"expected_visual_group":family,"forbidden_merge_group":f"forbid-{i:06d}"})
        for kind in RELATIONS:
            if len(truth)>=args.count: break
            target=out/f"{i:06d}_{kind}.jpg"; create_variant(kind,img,base,target,i)
            truth.append({"path":target.name,"family_id":family,"relation":kind,"expected_exact_group":exact if kind=="exact" else None,"expected_visual_group":family,"forbidden_merge_group":f"forbid-{i:06d}"})
        if len(truth)>=args.count: break
    for i in range(args.raw_families): add_raw_family(out,i,truth)
    for i in range(args.live_pairs): add_live_photo_fixture(out,i,truth)
    for i in range(args.burst_families): add_burst_fixture(out,i,truth)
    (out/"ground_truth.jsonl").write_text("\n".join(json.dumps(x,sort_keys=True) for x in truth)+"\n")
    print(json.dumps({"assets":len(truth),"out":str(out),"seed":args.seed,"relations":list(RELATIONS)},indent=2))
if __name__=="__main__": main()
