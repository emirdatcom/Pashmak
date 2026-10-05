package ir.example.pashmak_app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import ir.cafebazaar.poolakey.Connection
import ir.cafebazaar.poolakey.ConnectionState
import ir.cafebazaar.poolakey.Payment
import ir.cafebazaar.poolakey.config.PaymentConfiguration
import ir.cafebazaar.poolakey.config.SecurityCheck
import ir.cafebazaar.poolakey.request.PurchaseRequest

/**
 * Cafe Bazaar billing through Poolakey (flavor `bazaar` only).
 *
 * [نیاز به راستی‌آزمایی] V2/V4: written from the Poolakey 2.2.0 API as used by the open-source
 * `flutter_poolakey` plugin; it has not been compiled or run against a real Bazaar account in the
 * authoring environment (no Android SDK / market access). Validate with a real low-value purchase.
 */
object FlavorBilling {
    fun register(activity: FlutterFragmentActivity, engine: FlutterEngine) {
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "app/billing")
        var payment: Payment? = null
        var connection: Connection? = null

        fun ready(): Payment? = if (connection?.getState() == ConnectionState.Connected) payment else null

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "connect" -> {
                    val rsa = call.argument<String>("rsa_key")
                    val security = if (rsa.isNullOrEmpty()) SecurityCheck.Disable else SecurityCheck.Enable(rsa)
                    val p = Payment(activity, PaymentConfiguration(localSecurityCheck = security))
                    payment = p
                    var replied = false
                    connection = p.connect {
                        connectionSucceed { if (!replied) { replied = true; result.success(true) } }
                        connectionFailed { if (!replied) { replied = true; result.success(false) } }
                        disconnected { }
                    }
                }
                "products" -> {
                    val p = ready() ?: return@setMethodCallHandler result.error("NOT_CONNECTED", "billing not connected", null)
                    val skus = call.argument<List<String>>("skus") ?: emptyList()
                    p.getInAppSkuDetails(skuIds = skus) {
                        getSkuDetailsSucceed { list -> result.success(list.map { mapOf("sku" to it.sku, "price" to it.price) }) }
                        getSkuDetailsFailed { result.error("QUERY_FAILED", it.toString(), null) }
                    }
                }
                "purchase" -> {
                    val p = ready() ?: return@setMethodCallHandler result.error("NOT_CONNECTED", "billing not connected", null)
                    val sku = call.argument<String>("sku")!!
                    val subscription = call.argument<Boolean>("subscription") ?: false
                    var done = false
                    fun reply(m: Map<String, Any?>) { if (!done) { done = true; result.success(m) } }
                    val callback: ir.cafebazaar.poolakey.callback.PurchaseCallback.() -> Unit = {
                        purchaseSucceed { info -> reply(mapOf("status" to "success", "sku" to info.productId, "token" to info.purchaseToken, "order_id" to info.orderId)) }
                        purchaseCanceled { reply(mapOf("status" to "canceled")) }
                        purchaseFailed { reply(mapOf("status" to "error")) }
                        failedToBeginFlow { reply(mapOf("status" to "error")) }
                    }
                    val request = PurchaseRequest(sku, null, null)
                    if (subscription) p.subscribeProduct(activity.activityResultRegistry, request, callback)
                    else p.purchaseProduct(activity.activityResultRegistry, request, callback)
                }
                "restore" -> {
                    val p = ready() ?: return@setMethodCallHandler result.error("NOT_CONNECTED", "billing not connected", null)
                    p.getPurchasedProducts {
                        querySucceed { items -> result.success(items.map { mapOf("sku" to it.productId, "token" to it.purchaseToken, "order_id" to it.orderId) }) }
                        queryFailed { result.error("QUERY_FAILED", it.toString(), null) }
                    }
                }
                "consume" -> {
                    val p = ready() ?: return@setMethodCallHandler result.error("NOT_CONNECTED", "billing not connected", null)
                    p.consumeProduct(call.argument<String>("token")!!) {
                        consumeSucceed { result.success(true) }
                        consumeFailed { result.error("CONSUME_FAILED", it.toString(), null) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
