package com.goshawkgames.androidbleplugin

import android.Manifest
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import androidx.annotation.RequiresPermission
import androidx.core.content.ContextCompat
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import kotlin.collections.forEach
import kotlin.collections.isNotEmpty
import java.util.UUID

class AndroidBLEPlugin (godot: Godot) : GodotPlugin(godot) {
    private val activity = godot.getActivity()
    private val bluetoothAdapter: BluetoothAdapter? by lazy {
        val bluetoothManager =
            activity?.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        bluetoothManager?.adapter
    }

    private var hrGatt: BluetoothGatt? = null
    private var bikeGatt: BluetoothGatt? = null

    @UsedByGodot
    override fun getPluginName(): String {
        return "AndroidBLEPlugin"
    }

    override fun getPluginSignals(): Set<SignalInfo> {
        return setOf(
            SignalInfo("heart_rate_raw_data", ByteArray::class.java),
            SignalInfo("indoor_bike_raw_data", ByteArray::class.java),// New signal for raw data
            SignalInfo("permission_required", String::class.java), // Emits String
            SignalInfo("device_found", String::class.java, String::class.java),
            SignalInfo("service_found", String::class.java),
            SignalInfo("scan_failed", Integer::class.java),
            SignalInfo("plugin_message", String::class.java)

        )
    }

    // Permission verification
    fun hasBluetoothScanPermission(): Boolean {
        return activity?.let {
            ContextCompat.checkSelfPermission(it, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED
        } == true
    }

    fun hasBluetoothConnectPermission(): Boolean {
        return activity?.let {
            ContextCompat.checkSelfPermission(it, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        } == true
    }

    private val scanCallback: ScanCallback = object : ScanCallback() {
        @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val device = result.device
            val scanRecord = result.scanRecord
            Log.v("godotplugin","found device: ${device.name?: "Unknown device"}")

            // Service UUIDs
            val serviceUuids = scanRecord?.serviceUuids
            if (serviceUuids != null && serviceUuids.isNotEmpty()) {
                Log.v("godotplugin","  Service UUIDs:")
                serviceUuids.forEach { parcelUuid ->
                    val uuid = parcelUuid.uuid.toString()
                    Log.v("godotplugin",uuid)

                    // Check for Heart Rate service (UUID: 0000180D-0000-1000-8000-00805F9B34FB)
                    if (uuid.startsWith("0000180D", ignoreCase = true)) {
                        Log.v("godotplugin","    * Heart Rate Monitor detected!")
                        connectToDevice(device, isHR = true)
                        emitSignal("device_found", "Heart Rate Monitor detected: ${device.name ?: "Unknown"}", result.device.address)
                    } else if (uuid.startsWith("00001826")) {
                        Log.v("godotplugin","Indoor Bike detected: ${device.name ?: "Unknown"}")
                        connectToDevice(device, isHR = false)
                        emitSignal("device_found", "Indoor Bike detected: ${device.name ?: "Unknown"}", result.device.address)
                    }
                }
            }
        }

        override fun onScanFailed(errorCode: Int) {
            Log.v("godotplugin","scan failed")
            emitSignal("scan_failed", errorCode)
        }
    }

    @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
    private fun connectToDevice(device: BluetoothDevice, isHR: Boolean) {
        val gattCallback =
            object : BluetoothGattCallback() {
                @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
                override fun onConnectionStateChange(
                    gatt: BluetoothGatt,
                    status: Int,
                    newState: Int
                ) {
                    if (newState == BluetoothProfile.STATE_CONNECTED) {
                        gatt.discoverServices()
                    } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                        println("Device disconnected: ${device.address}")
                    }
                }

                @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
                override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        val serviceUuid = if (isHR) HR_SERVICE_UUID else FMS_SERVICE_UUID
                        val charUuid = if (isHR) HR_MEASUREMENT_UUID else INDOOR_BIKE_DATA_UUID
                        val service = gatt.getService(serviceUuid)
                        val characteristic = service?.getCharacteristic(charUuid)
                        if (characteristic != null) {
                            gatt.setCharacteristicNotification(characteristic, true)
                            val descriptor = characteristic.getDescriptor(CLIENT_CONFIG_UUID)
                            descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                            gatt.writeDescriptor(descriptor)
                        }
                    }
                }

                override fun onCharacteristicChanged(
                    gatt: BluetoothGatt,
                    characteristic: BluetoothGattCharacteristic
                ) {
                    if (characteristic.uuid == HR_MEASUREMENT_UUID) {
                        emitSignal("heart_rate_raw_data", characteristic.value)
                    } else if (characteristic.uuid == INDOOR_BIKE_DATA_UUID) {
                        val data = parseIndoorBikeData(characteristic)
                        emitSignal("indoor_bike_raw_data", characteristic.value)
                        Log.v("godotplugin", "Speed: ${data.speed?.toString()?: "Unknown"} - Cadence: ${data.cadence?.toString()?: "Unknown"} - Power: ${data.power?.toString()?: "Unknown"} ")
                       /* emitSignal(
                            "bike_data_updated",
                            data.speed?.toFloat() ?: 0f,
                            data.cadence?.toFloat() ?: 0f,
                            data.power ?: 0
                        )*/
                    }
                }
            }

        val gatt = device.connectGatt(activity, false, gattCallback)
        if (isHR) hrGatt = gatt else bikeGatt = gatt
    }

    @RequiresPermission(allOf = [Manifest.permission.BLUETOOTH_SCAN,Manifest.permission.BLUETOOTH_CONNECT])
    @UsedByGodot
    fun bluetoothReady(): Boolean {
        if (bluetoothAdapter == null) {
            emitSignal("plugin_message","cannot find bluetooth adapter")
            return false
        }

        if (!bluetoothAdapter!!.isEnabled) {
            emitSignal("plugin_message","bluetooth not enabled")
            return false
        }
        // Verify permissions
        if (!hasBluetoothScanPermission()) {
            emitSignal("permission_required", Manifest.permission.BLUETOOTH_SCAN)
            return false
        }

        if (!hasBluetoothConnectPermission()) {
            emitSignal("permission_required", Manifest.permission.BLUETOOTH_CONNECT)
            return false
        }

        // Bluetooth initialized
        return true
    }

    @RequiresPermission(allOf = [Manifest.permission.BLUETOOTH_SCAN,Manifest.permission.BLUETOOTH_CONNECT])
    @UsedByGodot
    fun startScan() {
        Log.v("godotplugin","starting scan...")
        if (bluetoothAdapter == null) {
            Log.v("godotplugin","starting scan failed")
            emitSignal("scan_failed", -1) // Custom error code for no Bluetooth
            //return
        }

        if (!hasBluetoothScanPermission()) {
            emitSignal("permission_required", Manifest.permission.BLUETOOTH_SCAN)
            //return
        }

        if (!hasBluetoothConnectPermission()) {
            emitSignal("permission_required", Manifest.permission.BLUETOOTH_CONNECT)
        }

        bluetoothAdapter!!.bluetoothLeScanner?.startScan(
            emptyList(),
            ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                .build(),
            scanCallback
        )
    }

    @RequiresPermission(Manifest.permission.BLUETOOTH_SCAN)
    @UsedByGodot
    fun stopScan() {
        bluetoothAdapter!!.bluetoothLeScanner?.stopScan(scanCallback)
    }

    @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
    @UsedByGodot
    fun disconnect() {
        hrGatt?.disconnect()
        hrGatt?.close()
        hrGatt = null
        bikeGatt?.disconnect()
        bikeGatt?.close()
        bikeGatt = null
    }

    private fun parseIndoorBikeData(characteristic: BluetoothGattCharacteristic): IndoorBikeData {
        val value = characteristic.value
        if (value.size < 2) return IndoorBikeData(null, null, null, null)

        val flags = characteristic.getIntValue(BluetoothGattCharacteristic.FORMAT_UINT16, 0)
        var offset = 2

        val speed =
            if (flags and 0x0001 != 0) {
                characteristic.getIntValue(BluetoothGattCharacteristic.FORMAT_UINT16, offset) *
                        0.01.also { offset += 2 }
            } else null

        if (flags and 0x0002 != 0) offset += 2

        val cadence =
            if (flags and 0x0004 != 0) {
                characteristic.getIntValue(BluetoothGattCharacteristic.FORMAT_UINT16, offset) *
                        0.5.also { offset += 2 }
            } else null

        if (flags and 0x0008 != 0) offset += 2
        if (flags and 0x0010 != 0) offset += 3
        if (flags and 0x0020 != 0) offset += 2

        val power =
            if (flags and 0x0040 != 0) {
                characteristic.getIntValue(BluetoothGattCharacteristic.FORMAT_SINT16, offset)
                    .also { offset += 2 }
            } else null

        val heartRate =
            if (flags and 0x0800 != 0) {
                characteristic.getIntValue(BluetoothGattCharacteristic.FORMAT_UINT8, offset)
                    .also { offset += 1 }
            } else null

        return IndoorBikeData(speed, cadence, power, heartRate)
    }

    data class IndoorBikeData(
        val speed: Double?,
        val cadence: Double?,
        val power: Int?,
        val heartRate: Int?
    )
    companion object {
        val HR_SERVICE_UUID: UUID = UUID.fromString("0000180D-0000-1000-8000-00805F9B34FB")
        val HR_MEASUREMENT_UUID: UUID = UUID.fromString("00002A37-0000-1000-8000-00805F9B34FB")
        val FMS_SERVICE_UUID: UUID = UUID.fromString("00001826-0000-1000-8000-00805F9B34FB")
        val INDOOR_BIKE_DATA_UUID: UUID = UUID.fromString("00002AD2-0000-1000-8000-00805F9B34FB")
        val CLIENT_CONFIG_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805F9B34FB")
    }
}