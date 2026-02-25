 # Android BLE Fitness Plugin for Godot

## Usage
### add plugin to Godot
create directory under res://addons/
create a plugin.cfg file:
```
[plugin]
name = "BLEFitnessPlugin"
description = "Android (Quest) BLE Fitness Plugin for Godot"
author = "Your Name"
version = "1.0"
license = "MIT"
```
This will allow godot to regster your plugin. Now you can go to project settings and make sure the plugin is enabled

create a export_plugin script:


### configure plugin

### adding to game
call bluetoothReady() to verify bluetooth in working and has permissions.


## Creating with Android Studio

### Setting up the Android Studio project
- set up a new "No Activity" project in Android Studio
- set API version to 35, use kotlin for language and build

### Clean up base project
- select File -> New Module -> Android Library
- delete the "app" module in Finder/Explorer
- go to File -> Project Structure
- select Modules and delete the app module
- Select Dependencies and delete the espresso-core, junit, and material Dependencies
- Add a Library Dependency
- type "org.godotengine" in the search bar and select search the godot artifact
- select Ok twice to close the Project Structure window
- Open the libs.versions.toml file and remove the unused dependencies
- hover over the yellow underlined dependencies and let Android Studio update those
- remove the android-application plugin under the plugins section
- sync gradle and resolve errors
- Open build.gradle.kts for Module and remove jvmTarget if requested
- set compiler options to JavaVersion.VERSION_17
-add to the root of the file
```
val pluginName = "android-ble-plugin"
val pluginPackageName = "com.goshawkgames.androidbleplugin"
val pluginClassName = "AndroidBLEPlugin"
```

pluginName will form part of the filename that Godot will look for (i.e. *android_ble_plugin-release.aar*) as defined in export_plugin.gd

Under the "android" section add:
```
buildFeatures {
        buildConfig = true
    }
```

under "defaultConfig" add:
```
manifestPlaceholders["godotPluginName"] = pluginName
manifestPlaceholders["godotPluginPackageName"] = pluginPackageName
manifestPlaceholders["pluginClassName"] = pluginClassName
buildConfigField("String", "GODOT_PLUGIN_NAME", "\"${pluginName}\"")
setProperty("archivesBaseName", pluginName)
```
- The pluginPackageName should match the java class path
- remove any test references

- Open build.gradle.kts for Project and remove the application alias
- Delete the test directories under the plugin module... twice
- select com.goshawkgames.androidbleplugin and add a new kotlin class "AndroidBLEPlugin"
- Open the Android Manifest file
- add inside of manifest

```
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-feature android:name="android.hardware.bluetooth_le" android:required="true" />

<application>
    <!--
        Plugin metadata:

        - In the `android:name` attribute, the `org.godotengine.plugin.v2` prefix
        is required so Godot can recognize the project as a valid Godot
        Android plugin. The plugin name following the prefix should match the value
        of the plugin name returned by the plugin initializer.

        - The `android:value` attribute should be the classpath to the plugin
        initializer.
    -->
    <meta-data
        android:name="org.godotengine.plugin.v2.${godotPluginName}"
        android:value="${godotPluginPackageName}.${pluginClassName}"/>
</application>
```

Now you should be ready to begin coding



References:

- https://youtu.be/BCidg2aCXWc?si=-BfXFimmuBm7OOSd

- https://youtu.be/Vy9Nrbrr8H8?si=ofzDWI4_GwHrDWl9

- https://docs.godotengine.org/en/stable/tutorials/platform/android/android_plugin.html

- https://developers.meta.com/horizon/documentation/native/android/mobile-studio-setup-android/?locale=en_US

- https://docs.godotengine.org/en/stable/tutorials/platform/android/android_plugin.html
