# App Store Connect Review Reply — Guideline 2.1 Response

> **Case:** Guideline 2.1 - Information Needed - New App Submission  
> **App Name:** Keptora  
> **Bundle Identifier:** com.alfagolab.keptora  
> **In-App Purchase Product ID:** `com.keptora.app.pro.lifetime`  

---

## 📋 Copy-Paste Reply to Apple App Review (Resolution Center)

Dear Apple App Review Team,

Thank you for your review and feedback. Below is the detailed information requested to help you understand Keptora, its architecture, and how to verify its functionality. We have also added this complete text to the **App Review Information -> Notes** field in App Store Connect for future reference.

---

### 1. Screen Recording Demonstrating App Functionality
- **Video Link:** [INSERT YOUR ICLOUD / DROPBOX / UNLISTED YOUTUBE VIDEO LINK HERE]
- **Video Highlights Demonstrated:**
  - Launching Keptora on a physical device.
  - Selecting local photos/folders and initiating a local on-device scan.
  - Browsing exact byte duplicates and visually similar photos with the protected keeper badge.
  - Demonstrating the Cinematic Photo Viewer and Swipe-to-Cull studio (swiping right to keep, swiping left to safely isolate to reversible quarantine).
  - Navigating to Smart Buckets (Screenshots, Receipts, Blurry photos).
  - Opening the Settings and the Keptora Pro Lifetime Paywall / StoreKit 2 purchase screen.
- **Account Flows Note:** Keptora is an entirely local, on-device utility. It has **no user accounts, no login, and no registration**, which is why no account creation or deletion flows exist.
- **User-Generated Content Note:** Keptora does **not** host, transmit, or share user-generated content or social networking features.

---

### 2. Purpose and Target Audience
- **App Purpose:** Keptora is a high-performance, privacy-first photo organizer, cinematic photo viewer, and decluttering assistant designed specifically for macOS and iOS.
- **The Problem It Solves:** Users accumulate thousands of photos, duplicate media files, accidental burst shots, blurred photos, and forgotten document scans/receipts that waste gigabytes of device storage and make photo libraries unmanageable.
- **The Value It Provides:**
  - **Deterministic Safety:** Finds byte-for-byte exact duplicate files using cryptographic SHA-256 fingerprinting. Every duplicate group always protects at least one "Keeper" so original photos are never accidentally lost.
  - **Reversible Quarantine:** When cleaning folder-based duplicates, items are safely moved to a local `.Keptora Quarantine` folder that can be restored with a single click.
  - **On-Device Machine Learning:** Groups similar photos, flags blurry shots, identifies screenshots and receipts, and detects sensitive documents (e.g. ID cards) completely offline using Apple's Vision framework.
  - **Cinematic Photo Viewer:** Provides high-fidelity 1:1 pixel zoom, side-by-side photo comparison, EXIF metadata inspector, and swipe-to-cull decluttering.
- **Target Audience:** Photographers, content creators, professionals, and general Apple users who want to declutter, organize, and view their photo libraries while maintaining 100% data privacy.

---

### 3. Setup and Access Instructions
- **Login Credentials:** **NONE REQUIRED.** Keptora does not require accounts, usernames, passwords, or cloud sign-in. The app is immediately functional upon launch.
- **Accessing Main Features:**
  1. **Launch App:** Open Keptora on the device.
  2. **Select Media Source:** Tap/Click **"Apple Photos"** (or **"Choose Folder"** / **"Files"**). Grant read access when prompted by the native iOS/macOS system permission dialog.
  3. **Scan:** Click **"Start Scan"**. The app performs on-device analysis.
  4. **Review Results:**
     - Tap **"Exact Duplicates"** to see identical byte copies (notice the protected "Keeper" badge).
     - Tap **"Similar Photos"** to review burst/similar shots with side-by-side comparison.
     - Tap **"Smart Buckets"** to view categorized media (Screenshots, Receipts, Heavy Videos).
     - Tap **"Swipe Studio"** to test card-swipe culling (Swipe Right = Keep, Swipe Left = Clean to Quarantine, Swipe Up = Skip).
  5. **Review Quarantine & Restore:** Go to **History** to see any quarantined items with the one-click **Restore** button.
  6. **In-App Purchase / Pro Upgrade:** Tap the **Crown / "Upgrade to Pro"** button in the navigation bar or Settings to view the Keptora Pro Lifetime StoreKit 2 sheet. StoreKit Sandbox accounts can be used to test transactions.
- **Sample Files:** A pre-packaged sample review folder `Keptora_App_Review_Corpus.zip` is available in the repository if folder testing is preferred, or the reviewer can use standard camera roll photos.

---

### 4. External Services, Tools, and Platforms
- **External Servers / Backend:** **NONE.** Keptora has zero backend servers, zero remote databases, and makes zero network calls to external APIs.
- **Third-Party AI / Cloud Services:** **NONE.** All categorization, OCR, and similarity analysis are powered exclusively by Apple's built-in on-device frameworks (`Vision`, `ImageIO`, `CoreML`, and `AVFoundation`). Photos and videos never leave the user's physical device.
- **Analytics & Tracking SDKs:** **NONE.** No Firebase, no Google Analytics, no Facebook SDK, no advertising networks.
- **Authentication Services:** **NONE.**
- **Payment Processing:** Exclusively processed via **Apple StoreKit 2** using the native In-App Purchase system (`com.keptora.app.pro.lifetime`).

---

### 5. Regional Differences
- **Consistency:** Keptora functions **100% consistently across all countries and regions**.
- **Localization:** The user interface is natively localized in 4 languages:
  - English (`en-US`)
  - Turkish (`tr`)
  - German (`de`)
  - French (`fr`)
- No features, content, or tiers are geo-restricted or altered by geographic region.

---

### 6. Highly Regulated Industries and Third-Party Material
- **Regulatory Status:** Keptora is a standalone local file and photo management utility. It does not operate in banking, healthcare, gambling, or any other regulated industry.
- **Third-Party Material:** All icons, branding, code, and user interface designs are original and owned by AlfaGo Lab. Keptora does not incorporate proprietary third-party intellectual property or copyrighted materials.

---

We remain at your full disposal if you need any additional clarifications or assistance. Thank you for your time and guidance in keeping the App Store a trusted and high-quality platform.

Warm regards,  
**AlfaGo Lab Team**  
Support: https://alfagolab.com/keptora/support  
Privacy Policy: https://alfagolab.com/keptora/privacy  
