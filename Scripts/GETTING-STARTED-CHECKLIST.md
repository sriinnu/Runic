# Getting Started with Runic Build Scripts - Checklist

Use this checklist to set up and start building Runic across all platforms.

## Prerequisites Checklist

### For All Platforms
- [ ] Git installed
- [ ] Clone Runic repository
- [ ] Navigate to project directory: `cd Runic`

### For macOS/iOS Development
- [ ] Running on macOS 14.0 or later
- [ ] Xcode 15.0 or later installed
- [ ] Command Line Tools installed: `xcode-select --install`
- [ ] Xcode configured: `sudo xcode-select --switch /Applications/Xcode.app`

### For Android Development
- [ ] Java Development Kit 17 installed ([Download](https://adoptium.net))
- [ ] Android Studio installed (or Android SDK)
- [ ] ANDROID_HOME environment variable set
  ```bash
  export ANDROID_HOME=$HOME/Library/Android/sdk
  export PATH=$PATH:$ANDROID_HOME/platform-tools
  ```
- [ ] Add to `~/.bashrc` or `~/.zshrc` to persist

### For React Native Development
- [ ] Node.js 18+ installed ([Download](https://nodejs.org) or use nvm)
- [ ] npm or yarn installed
- [ ] Watchman installed (macOS): `brew install watchman`

### For Windows Development
- [ ] Windows 10 or later
- [ ] Visual Studio 2022 with C++ development tools
- [ ] Windows 10 SDK (10.0.19041.0 or higher)
- [ ] Node.js 18+ installed

---

## First-Time Setup Checklist

### Step 1: Make Scripts Executable
```bash
chmod +x scripts/*.sh
```
- [ ] Scripts are executable

### Step 2: Read Documentation
- [ ] Skim `scripts/README-SCRIPTS.md`
- [ ] Bookmark `scripts/QUICK-REFERENCE.md`
- [ ] Review `scripts/DIRECTORY-STRUCTURE.md`

### Step 3: Test Setup with Dry-Run
```bash
./scripts/setup-all.sh --dry-run --verbose
```
- [ ] Dry-run completes without errors
- [ ] Review what will be executed
- [ ] Verify all prerequisites are satisfied

### Step 4: Run Actual Setup
```bash
./scripts/setup-all.sh --verbose
```
- [ ] Setup completes successfully
- [ ] Dependencies installed
- [ ] Configuration files created

---

## Code Signing Setup Checklist

### iOS Code Signing
- [ ] Apple Developer account created
- [ ] Team ID obtained
- [ ] Open Xcode project: `open RuniciOS/*.xcodeproj`
- [ ] Select target → Signing & Capabilities
- [ ] Choose team
- [ ] Enable "Automatically manage signing"
- [ ] Edit `RuniciOS/Config.xcconfig` with team ID
- [ ] Test build: `./scripts/build-ios.sh --simulator`

### Android Code Signing
```bash
# Generate keystore
keytool -genkey -v -keystore release.keystore \
  -alias runic-key -keyalg RSA -keysize 2048 -validity 10000
```
- [ ] Keystore generated
- [ ] Create `runic-cross-platform/android/keystore.properties`:
  ```properties
  storePassword=YOUR_PASSWORD
  keyPassword=YOUR_PASSWORD
  keyAlias=runic-key
  storeFile=release.keystore
  ```
- [ ] Update `android/app/build.gradle` (see README-SCRIPTS.md)
- [ ] Test signed build: `./scripts/build-android.sh --variant release`

---

## First Build Checklist

### macOS Build
```bash
./scripts/build-macos.sh --verbose
```
- [ ] Build completes successfully
- [ ] App bundle created: `builds/macos/Runic.app`
- [ ] ZIP archive created: `builds/macos/Runic-*.zip`
- [ ] Test run: `open builds/macos/Runic.app`

### iOS Build (Simulator)
```bash
./scripts/build-ios.sh --simulator --verbose
```
- [ ] Build completes successfully
- [ ] Build products in `builds/ios/DerivedData/`
- [ ] Open in Xcode and run on simulator

### iOS Build (Device)
```bash
./scripts/build-ios.sh --device --archive --verbose
```
- [ ] Build completes successfully
- [ ] Archive created: `builds/ios/RuniciOS.xcarchive`
- [ ] IPA exported (if signed): `builds/ios/Export/*.ipa`

### Android Build
```bash
./scripts/build-android.sh --variant debug --verbose
```
- [ ] Build completes successfully
- [ ] APK created: `builds/android/app-debug.apk`
- [ ] Install on device: `adb install builds/android/app-debug.apk`

### Windows Build
```bash
./scripts/build-windows.sh --verbose
```
- [ ] Build completes successfully
- [ ] Executable in `builds/windows/`
- [ ] Test on Windows

---

## CI/CD Setup Checklist

### Step 1: Copy Workflow
```bash
mkdir -p .github/workflows
cp scripts/ci-config.yml .github/workflows/ci.yml
```
- [ ] Workflow file copied

### Step 2: Configure GitHub Secrets

#### iOS Secrets
- [ ] Export certificate as P12
- [ ] Base64 encode: `base64 -i certificate.p12 -o cert.txt`
- [ ] Add to GitHub secrets: `IOS_CERTIFICATE_P12`
- [ ] Add password: `IOS_CERTIFICATE_PASSWORD`
- [ ] Export provisioning profile
- [ ] Base64 encode: `base64 -i profile.mobileprovision -o profile.txt`
- [ ] Add to GitHub secrets: `IOS_PROVISIONING_PROFILE`
- [ ] (Optional) Add App Store Connect API key: `APP_STORE_CONNECT_API_KEY`

#### Android Secrets
- [ ] Base64 encode keystore: `base64 -i release.keystore -o keystore.txt`
- [ ] Add to GitHub secrets: `ANDROID_KEYSTORE_BASE64`
- [ ] Add keystore password: `ANDROID_KEYSTORE_PASSWORD`
- [ ] Add key alias: `ANDROID_KEY_ALIAS`
- [ ] Add key password: `ANDROID_KEY_PASSWORD`
- [ ] (Optional) Add Play Console service account: `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`

### Step 3: Test CI/CD
- [ ] Commit workflow: `git add .github/workflows/ci.yml`
- [ ] Push: `git push`
- [ ] Check GitHub Actions tab
- [ ] Verify all jobs pass
- [ ] Download artifacts

---

## Daily Development Workflow Checklist

### Morning Routine
- [ ] Pull latest changes: `git pull`
- [ ] Update dependencies (if needed):
  ```bash
  swift package update          # macOS
  cd RuniciOS && pod update     # iOS
  cd runic-cross-platform && npm update  # React Native
  ```

### Development Builds
- [ ] macOS: `./scripts/build-macos.sh --skip-tests --skip-signing`
- [ ] iOS: `./scripts/build-ios.sh --simulator --skip-tests`
- [ ] Android: `./scripts/build-android.sh --variant debug --skip-tests`
- [ ] Windows: `./scripts/build-windows.sh --configuration Debug --skip-tests`

### Before Committing
- [ ] Run tests:
  ```bash
  swift test                    # macOS
  npm test                      # React Native
  ```
- [ ] Run linters:
  ```bash
  swiftlint lint                # Swift
  cd runic-cross-platform && npm run lint  # JavaScript
  ```
- [ ] Format code:
  ```bash
  swiftformat .                 # Swift
  cd runic-cross-platform && npm run format  # JavaScript
  ```
- [ ] Commit changes
- [ ] Push to trigger CI

---

## Release Workflow Checklist

### Pre-Release
- [ ] Update version number in `version.env`
- [ ] Update CHANGELOG.md
- [ ] Create release branch: `git checkout -b release/1.2.3`
- [ ] Update version strings in:
  - [ ] `version.env`
  - [ ] iOS `Info.plist` or project settings
  - [ ] Android `build.gradle` (versionCode, versionName)

### Build Release Artifacts
- [ ] macOS: `./scripts/build-macos.sh --clean`
- [ ] iOS: `./scripts/build-ios.sh --archive --clean`
- [ ] Android APK: `./scripts/build-android.sh --variant release --clean`
- [ ] Android AAB: `./scripts/build-android.sh --aab --clean`
- [ ] Windows: `./scripts/build-windows.sh --clean`

### Test Release Builds
- [ ] Test macOS app: `open builds/macos/Runic.app`
- [ ] Test iOS on device
- [ ] Test Android APK: `adb install builds/android/app-release.apk`
- [ ] Test Windows executable

### Deploy
- [ ] macOS: Upload to website/distribution platform
- [ ] iOS: Upload to TestFlight
  ```bash
  xcrun altool --upload-app -f builds/ios/Export/RuniciOS.ipa \
    -t ios -u username -p password
  ```
- [ ] Android: Upload AAB to Play Console
- [ ] Windows: Create installer and distribute

### Post-Release
- [ ] Tag release: `git tag v1.2.3`
- [ ] Push tag: `git push origin v1.2.3`
- [ ] Create GitHub release
- [ ] Attach build artifacts to release
- [ ] Merge release branch to main
- [ ] Update documentation if needed

---

## Troubleshooting Checklist

### If Build Fails

1. **Try Dry-Run First**
   ```bash
   ./scripts/build-macos.sh --dry-run --verbose
   ```
   - [ ] Dry-run shows what will execute
   - [ ] Prerequisites are satisfied

2. **Check Prerequisites**
   ```bash
   ./scripts/setup-all.sh --dry-run --verbose
   ```
   - [ ] All required tools installed
   - [ ] Versions are correct

3. **Clean Build**
   ```bash
   ./scripts/build-macos.sh --clean --verbose
   ```
   - [ ] Old build artifacts removed
   - [ ] Fresh build succeeds

4. **Read Error Messages**
   - [ ] Error message explains the issue
   - [ ] Follow suggested solution
   - [ ] Check README-SCRIPTS.md troubleshooting section

5. **Check Documentation**
   - [ ] Review `scripts/README-SCRIPTS.md`
   - [ ] Check platform-specific guide
   - [ ] Search for similar issues

---

## Additional Resources Checklist

### Documentation
- [ ] `scripts/README-SCRIPTS.md` - Complete guide
- [ ] `scripts/QUICK-REFERENCE.md` - Quick commands
- [ ] `scripts/CREATION-SUMMARY.md` - What was created
- [ ] `scripts/DIRECTORY-STRUCTURE.md` - File organization
- [ ] `scripts/GETTING-STARTED-CHECKLIST.md` - This file

### Help Commands
- [ ] Setup help: `./scripts/setup-all.sh --help`
- [ ] Build help: `./scripts/build-macos.sh --help`
- [ ] Dry-run: `./scripts/build-macos.sh --dry-run --verbose`

### Online Resources
- [ ] Xcode documentation
- [ ] React Native documentation
- [ ] Android developer guide
- [ ] GitHub Actions documentation

---

## Success Criteria

You've successfully set up Runic build scripts when:

- ✅ All setup scripts run without errors
- ✅ All build scripts produce artifacts
- ✅ CI/CD workflow passes on GitHub
- ✅ Code signing works for release builds
- ✅ Applications run on target platforms

**Congratulations! You're ready to build Runic across all platforms! 🎉**

---

## Need Help?

1. **Check Documentation**
   ```bash
   cat scripts/README-SCRIPTS.md
   cat scripts/QUICK-REFERENCE.md
   ```

2. **Run with Verbose**
   ```bash
   ./scripts/build-macos.sh --verbose --dry-run
   ```

3. **Review Troubleshooting**
   - See `scripts/README-SCRIPTS.md` → Troubleshooting section

4. **Open an Issue**
   - Include script output
   - Include system information
   - Include `--verbose` logs

---

**Remember**: Start with `--dry-run` and `--verbose` to understand what scripts do before executing them!
