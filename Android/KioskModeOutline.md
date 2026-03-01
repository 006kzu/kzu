# Android Kiosk Mode — Implementation Outline

## Overview

Android's equivalent to iOS FamilyControls is the **Device Policy Controller (DPC)** with **Lock Task Mode**. This creates a "Dedicated Device" experience where Kzu becomes the launcher, restricting access to other apps.

---

## Architecture

```
┌──────────────────────────────────────────┐
│              Kzu Android App             │
│                                          │
│  ┌─────────────┐  ┌──────────────────┐   │
│  │ State Machine│  │ Content Engine   │   │
│  │ (ViewModel)  │  │ (Same JSON)     │   │
│  └──────┬──────┘  └──────────────────┘   │
│         │                                │
│  ┌──────▼──────────────────────────────┐ │
│  │     KioskModeManager                │ │
│  │  - startLockTask()                  │ │
│  │  - stopLockTask()                   │ │
│  │  - DevicePolicyManager              │ │
│  └─────────────────────────────────────┘ │
│                                          │
│  ┌─────────────────────────────────────┐ │
│  │   KzuDeviceAdminReceiver            │ │
│  │   (DeviceAdminReceiver subclass)    │ │
│  └─────────────────────────────────────┘ │
└──────────────────────────────────────────┘
```

---

## Step 1: Device Admin Receiver

```kotlin
// KzuDeviceAdminReceiver.kt

class KzuDeviceAdminReceiver : DeviceAdminReceiver() {

    companion object {
        fun getComponentName(context: Context): ComponentName {
            return ComponentName(context.applicationContext, KzuDeviceAdminReceiver::class.java)
        }
    }

    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Log.d("Kzu", "Device admin enabled")
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        Log.d("Kzu", "Device admin disabled")
    }

    override fun onLockTaskModeEntering(context: Context, intent: Intent, pkg: String) {
        // Kzu is now in kiosk mode
        Log.d("Kzu", "Lock task mode entering for $pkg")
    }

    override fun onLockTaskModeExiting(context: Context, intent: Intent) {
        // Kzu exited kiosk mode (parent released)
        Log.d("Kzu", "Lock task mode exiting")
    }
}
```

### Manifest Registration

```xml
<!-- AndroidManifest.xml -->
<receiver
    android:name=".KzuDeviceAdminReceiver"
    android:permission="android.permission.BIND_DEVICE_ADMIN">
    <meta-data
        android:name="android.app.device_admin"
        android:resource="@xml/device_admin_policies" />
    <intent-filter>
        <action android:name="android.app.action.DEVICE_ADMIN_ENABLED" />
    </intent-filter>
</receiver>
```

```xml
<!-- res/xml/device_admin_policies.xml -->
<device-admin>
    <uses-policies>
        <limit-password />
        <force-lock />
    </uses-policies>
</device-admin>
```

---

## Step 2: Kiosk Mode Manager

```kotlin
// KioskModeManager.kt

class KioskModeManager(private val activity: Activity) {

    private val dpm = activity.getSystemService(Context.DEVICE_POLICY_SERVICE)
        as DevicePolicyManager
    private val adminComponent = KzuDeviceAdminReceiver.getComponentName(activity)

    /**
     * Check if this app is a Device Owner.
     * Must be provisioned via ADB:
     *   adb shell dpm set-device-owner com.kzu/.KzuDeviceAdminReceiver
     */
    val isDeviceOwner: Boolean
        get() = dpm.isDeviceOwnerApp(activity.packageName)

    /**
     * Enables Lock Task Mode — makes Kzu the exclusive foreground app.
     * The child cannot leave, press Home, or access Recent Apps.
     */
    fun enterKioskMode() {
        if (!isDeviceOwner) {
            Log.w("Kzu", "Not a device owner — cannot enter kiosk mode")
            return
        }

        // Whitelist this package for lock task
        dpm.setLockTaskPackages(adminComponent, arrayOf(activity.packageName))

        // Configure lock task features
        dpm.setLockTaskFeatures(
            adminComponent,
            // Allow the status bar (for time display)
            DevicePolicyManager.LOCK_TASK_FEATURE_SYSTEM_INFO or
            // Block everything else
            DevicePolicyManager.LOCK_TASK_FEATURE_NONE
        )

        // Start lock task
        activity.startLockTask()
    }

    /**
     * Exits Lock Task Mode — called by the parent from the dashboard.
     */
    fun exitKioskMode() {
        activity.stopLockTask()
    }

    /**
     * Sets Kzu as the default Home app (launcher replacement).
     * After this, pressing Home returns to Kzu instead of the system launcher.
     */
    fun setAsHomeLauncher() {
        if (!isDeviceOwner) return

        val filter = IntentFilter(Intent.ACTION_MAIN)
        filter.addCategory(Intent.CATEGORY_HOME)
        filter.addCategory(Intent.CATEGORY_DEFAULT)

        dpm.addPersistentPreferredActivity(
            adminComponent,
            filter,
            ComponentName(activity.packageName, "${activity.packageName}.MainActivity")
        )
    }
}
```

---

## Step 3: State Machine (ViewModel)

```kotlin
// KzuViewModel.kt

class KzuViewModel(application: Application) : AndroidViewModel(application) {

    enum class Phase {
        IDLE, LEARNING_BLOCK, EXPLORER_MODE, GAME_HUB
    }

    private val _phase = MutableStateFlow(Phase.IDLE)
    val phase: StateFlow<Phase> = _phase.asStateFlow()

    private val _timeRemaining = MutableStateFlow(25 * 60L) // seconds
    val timeRemaining: StateFlow<Long> = _timeRemaining.asStateFlow()

    private var timerJob: Job? = null
    private var backgroundTimestamp: Long? = null

    companion object {
        const val LEARNING_DURATION = 25 * 60L
        const val GAME_HUB_DURATION = 5 * 60L
        const val BACKGROUND_GRACE = 10L
    }

    fun beginFlow() {
        _phase.value = Phase.LEARNING_BLOCK
        _timeRemaining.value = LEARNING_DURATION
        startTimer(LEARNING_DURATION) { onLearningComplete() }
    }

    private fun startTimer(duration: Long, onComplete: () -> Unit) {
        timerJob?.cancel()
        _timeRemaining.value = duration

        timerJob = viewModelScope.launch {
            while (_timeRemaining.value > 0) {
                delay(1000)
                _timeRemaining.value -= 1
            }
            onComplete()
        }
    }

    private fun onLearningComplete() {
        _phase.value = Phase.GAME_HUB
        _timeRemaining.value = GAME_HUB_DURATION
        startTimer(GAME_HUB_DURATION) { onGameHubComplete() }
    }

    private fun onGameHubComplete() {
        _phase.value = Phase.LEARNING_BLOCK
        _timeRemaining.value = LEARNING_DURATION
        startTimer(LEARNING_DURATION) { onLearningComplete() }
    }

    // Reset penalty
    fun onAppBackgrounded() {
        backgroundTimestamp = System.currentTimeMillis()
    }

    fun onAppForegrounded() {
        backgroundTimestamp?.let { bg ->
            val elapsed = (System.currentTimeMillis() - bg) / 1000
            if (_phase.value == Phase.LEARNING_BLOCK && elapsed > BACKGROUND_GRACE) {
                applyResetPenalty()
            }
        }
        backgroundTimestamp = null
    }

    private fun applyResetPenalty() {
        _timeRemaining.value = LEARNING_DURATION
        startTimer(LEARNING_DURATION) { onLearningComplete() }
    }
}
```

---

## Step 4: Provisioning

### Development (ADB)
```bash
# Reset any existing device owners
adb shell pm clear com.kzu

# Set Kzu as device owner
adb shell dpm set-device-owner com.kzu/.KzuDeviceAdminReceiver
```

### Production (Zero-Touch Enrollment)
- Use **Android Zero-Touch Enrollment** or **Samsung Knox** for enterprise provisioning
- Parents configure the device via the Kzu companion parent app
- The DPC is set as the device owner during initial device setup

---

## Step 5: Dedicated Launcher Feel

```kotlin
// In MainActivity.kt

override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    // Make fullscreen (immersive mode)
    window.decorView.systemUiVisibility = (
        View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        or View.SYSTEM_UI_FLAG_FULLSCREEN
        or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
    )

    // Initialize kiosk mode
    val kioskManager = KioskModeManager(this)
    if (kioskManager.isDeviceOwner) {
        kioskManager.enterKioskMode()
        kioskManager.setAsHomeLauncher()
    }
}

// Lifecycle observers for reset penalty
override fun onPause() {
    super.onPause()
    viewModel.onAppBackgrounded()
}

override fun onResume() {
    super.onResume()
    viewModel.onAppForegrounded()
}
```

---

## Key Differences from iOS

| Feature | iOS | Android |
|---------|-----|---------|
| App blocking | FamilyControls + ManagedSettings | Lock Task Mode (complete) |
| Background enforcement | DeviceActivityMonitor extension | Foreground Service + AlarmManager |
| Parental auth | AuthorizationCenter (Screen Time) | Device Owner provisioning |
| Shield UI | ShieldConfigurationExtension | Lock Task Mode (no app access) |
| Provisioning | Per-device, user-initiated | ADB or Zero-Touch Enrollment |

---

## MVP Scope

For Android MVP, implement:
1. ✅ Lock Task Mode activation
2. ✅ Pomodoro state machine (ViewModel)
3. ✅ Background penalty detection
4. ⬜ Jetpack Compose UI (port SwiftUI views)
5. ⬜ Content Engine (port from iOS, same JSON schema)
6. ⬜ SpriteKit → Canvas2D game ports
7. ⬜ Room database (SwiftData equivalent)
