package org.jellyfin.mobile.utils

import android.content.Context
import android.content.pm.PackageManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import timber.log.Timber
import java.lang.reflect.Proxy

object AutomotiveUxRestrictionsState {
    private val _isParked = MutableStateFlow(true)
    val isParkedFlow: StateFlow<Boolean> = _isParked

    val isParked: Boolean
        get() = _isParked.value

    fun isAutomotive(context: Context): Boolean =
        context.packageManager.hasSystemFeature(PackageManager.FEATURE_AUTOMOTIVE)

    fun isInteractionAllowed(context: Context): Boolean = !isAutomotive(context) || isParked

    fun updateIsParked(isParked: Boolean) {
        _isParked.value = isParked
    }
}

class AutomotiveUxRestrictionsMonitor(
    context: Context,
    private val onParkedStateChanged: (Boolean) -> Unit = {},
) {
    private val appContext = context.applicationContext

    private var car: Any? = null
    private var carUxRestrictionsManager: Any? = null
    private var listener: Any? = null
    private var started = false

    fun start() {
        if (started) return
        started = true

        if (!AutomotiveUxRestrictionsState.isAutomotive(appContext)) {
            notifyParkedState(true)
            return
        }

        try {
            val carClass = Class.forName("android.car.Car")
            car = carClass.getMethod("createCar", Context::class.java).invoke(null, appContext)

            val serviceName = carClass.getField("CAR_UX_RESTRICTION_SERVICE").get(null) as String
            carUxRestrictionsManager = carClass
                .getMethod("getCarManager", String::class.java)
                .invoke(car, serviceName)

            val manager = requireNotNull(carUxRestrictionsManager)
            val listenerClass = Class.forName(
                "android.car.drivingstate.CarUxRestrictionsManager\$OnUxRestrictionsChangedListener",
            )

            listener = Proxy.newProxyInstance(
                listenerClass.classLoader,
                arrayOf(listenerClass),
            ) { _, method, args ->
                if (method.name == "onUxRestrictionsChanged") {
                    updateFromRestrictions(args?.firstOrNull())
                }
                null
            }

            updateFromRestrictions(
                manager.javaClass.getMethod("getCurrentCarUxRestrictions").invoke(manager),
            )
            manager.javaClass.getMethod("registerListener", listenerClass).invoke(manager, listener)
        } catch (throwable: Throwable) {
            Timber.w(throwable, "Failed to monitor AAOS UX restrictions, blocking parked app interactions")
            notifyParkedState(false)
        }
    }

    fun stop() {
        if (!started) return
        started = false

        try {
            carUxRestrictionsManager?.javaClass?.getMethod("unregisterListener")?.invoke(carUxRestrictionsManager)
        } catch (throwable: Throwable) {
            Timber.d(throwable, "Failed to unregister AAOS UX restrictions listener")
        }

        try {
            car?.javaClass?.getMethod("disconnect")?.invoke(car)
        } catch (throwable: Throwable) {
            Timber.d(throwable, "Failed to disconnect AAOS car service")
        }

        listener = null
        carUxRestrictionsManager = null
        car = null
    }

    private fun updateFromRestrictions(restrictions: Any?) {
        if (restrictions == null) {
            notifyParkedState(false)
            return
        }

        val requiresDistractionOptimization = restrictions.javaClass
            .getMethod("isRequiresDistractionOptimization")
            .invoke(restrictions) as Boolean

        notifyParkedState(!requiresDistractionOptimization)
    }

    private fun notifyParkedState(isParked: Boolean) {
        AutomotiveUxRestrictionsState.updateIsParked(isParked)
        onParkedStateChanged(isParked)
    }
}