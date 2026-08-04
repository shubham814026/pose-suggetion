# Setup, Installation & Troubleshooting Guide

This guide provides step-by-step instructions to set up, configure, build, run, and troubleshoot the **AI Pose Suggestion App** on physical Android devices, emulators, or iOS devices.

---

## 1. Environment Requirements & Prerequisites

Ensure your development environment meets the following specifications:

- **Flutter SDK**: `>= 3.0.0` (Dart SDK `>= 3.0.0 < 4.0.0`)
- **JDK (Java Development Kit)**: **JDK 17** (Required for Gradle compatibility)
- **Android Target**: Android 8.0 (API Level 26) or higher (Required by `tflite_flutter`)
- **Compile SDK**: Android SDK 36
- **Android Gradle Plugin (AGP)**: `8.6.0`
- **Kotlin Plugin**: `2.2.20`
- **Physical Android Phone (Recommended)**: Developer Mode & USB Debugging enabled for real-time camera testing.

---

## 2. Step-by-Step Build & Configuration Setup

### Step 1: Force Gradle to Use JDK 17
To avoid `Unsupported class file major version 69` errors (caused by default Java 25 runtimes), specify the JDK 17 path in `android/gradle.properties`:

Open `android/gradle.properties` and add/update:
```properties
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
org.gradle.java.home=C:/Program Files/Java/jdk-17
kotlin.jvm.target.validation.mode=ignore
android.useAndroidX=true
android.enableJetifier=true
```
*(Note: Replace `C:/Program Files/Java/jdk-17` with your local JDK 17 path or Android Studio's bundled JBR path `C:/Program Files/Android/Android Studio/jbr` if needed).*

---

### Step 2: Configure Android Gradle Plugin & Kotlin Version
Open `android/settings.gradle` and configure the plugin block:

```groovy
plugins {
    id "dev.flutter.flutter-plugin-loader" version "1.0.0"
    id "com.android.application" version "8.6.0" apply false
    id "org.jetbrains.kotlin.android" version "2.2.20" apply false
}
```

---

### Step 3: Configure `app/build.gradle` (SDK Levels)
Open `android/app/build.gradle` and set `compileSdk 36` and `minSdkVersion 26`:

```groovy
android {
    namespace "com.example.pose_suggetion"
    compileSdk 36
    ndkVersion flutter.ndkVersion

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = '17'
    }

    defaultConfig {
        applicationId "com.example.pose_suggetion"
        minSdkVersion 26
        targetSdkVersion 34
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
    }
}
```

---

### Step 4: Configure Subprojects Target Compatibility
Open `android/build.gradle` and ensure all third-party subproject plugins (such as `tflite_flutter`) build with Java 17:

```groovy
subprojects { subproject ->
    def configureAndroid = {
        if (subproject.hasProperty('android')) {
            subproject.android {
                compileOptions {
                    sourceCompatibility JavaVersion.VERSION_17
                    targetCompatibility JavaVersion.VERSION_17
                }
            }
        }
    }

    if (subproject.state.executed) {
        configureAndroid()
    } else {
        subproject.afterEvaluate configureAndroid
    }

    tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile).configureEach {
        kotlinOptions {
            jvmTarget = "17"
        }
    }
}
```

---

### Step 5: Android Resources & Splash Theme Setup
Ensure the following resource files exist under `android/app/src/main/res/`:

1. **`res/values/styles.xml`**:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
</resources>
```

2. **`res/drawable/launch_background.xml`**:
```xml
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@android:color/white" />
</layer-list>
```

3. **`res/mipmap-anydpi-v26/ic_launcher.xml`**:
```xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@android:color/white"/>
    <foreground android:drawable="@android:drawable/sym_def_app_icon"/>
</adaptive-icon>
```

---

## 3. How to Run on a Physical Android Phone

### Step 1: Enable USB Debugging on Your Phone
1. On your phone, go to **Settings** $\rightarrow$ **About Phone**.
2. Tap **Build Number** 7 times until Developer Mode is unlocked.
3. Go to **Settings** $\rightarrow$ **System / Developer Options**.
4. Enable **USB Debugging**.

### Step 2: Connect via USB & Confirm Device Detection
1. Connect your phone to your PC using a USB cable.
2. Accept the **"Allow USB Debugging?"** popup prompt on your phone screen.
3. Open your terminal in the workspace root and run:
   ```bash
   flutter devices
   ```
   *Verify your physical phone ID (e.g., `I2220`) is listed.*

### Step 3: Launch the Application
Run:
```bash
flutter run
```
Or specify your device explicitly:
```bash
flutter run -d I2220
```

---

## 4. Review & Testing Walkthrough

1. **Camera Access**: Grant camera permission when prompted upon first launch.
2. **Pose Selection**: Open gallery tab and pick a reference pose (e.g. *Crossed Arms Power Pose*).
3. **Live AI Alignment**: Position yourself in front of the camera. The app will calculate joint angles in real time ($0\% - 100\%$).
4. **Voice Guidance & Auto-Capture**: Spoken feedback will guide posture corrections (`flutter_tts`). Reaching $\ge 80\%$ match score triggers a 2-second countdown auto-capture photo taking flow.

---

## 5. Troubleshooting Reference

| Error Observed | Root Cause | Solution |
| :--- | :--- | :--- |
| `Unsupported class file major version 69` | Gradle executed with Java 25 | Set `org.gradle.java.home` to JDK 17 in `android/gradle.properties` |
| `AGP version 8.3.0 is lower than minimum 8.6.0` | Outdated AGP version | Set `id "com.android.application" version "8.6.0"` in `android/settings.gradle` |
| `minSdkVersion 24 cannot be smaller than 26` | `tflite_flutter` requires minSdk 26 | Set `minSdkVersion 26` in `android/app/build.gradle` |
| `Class 'kotlin.Unit' was compiled with incompatible version` | Kotlin stdlib mismatch | Set `id "org.jetbrains.kotlin.android" version "2.2.20"` in `android/settings.gradle` |
| `Inconsistent JVM Target Compatibility` | Java vs Kotlin target mismatch | Added subproject `compileOptions` and `KotlinCompile` config in `android/build.gradle` |
| `resource style/LaunchTheme not found` | Missing Android res resources | Added `styles.xml`, `launch_background.xml`, and `ic_launcher.xml` |
