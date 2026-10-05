package ir.example.pashmak_app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import ir.myket.billingclient.IabHelper
import ir.myket.billingclient.util.Purchase

/**
 * Myket billing through the IabHelper (flavor `myket` only).
 *
 * [نیاز به راستی‌آزمایی] V3/V4: modelled on the open-source `myket_iap` plugin (myket-billing-client
 * 1.19); not compiled or run against a real Myket account in the authoring environment.
 */
object FlavorBilling {
    fun register(activity: FlutterFragmentActivity, engine: FlutterEngine) {
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "app/billing")
        var helper: IabHelper? = null
        val known = HashMap<String, Purchase>() // token -> purchase, needed by consumeAsync

        fun remember(p: Purchase) { known[p.token] = p }

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "connect" -> {
                    val rsa = call.argument<String>("rsa_key")
                    if (rsa.isNullOrEmpty()) return@setMethodCallHandler result.success(false)
                    val h = IabHelper(activity, rsa)
                    helper = h
                    h.startSetup { r -> result.success(r.isSuccess) }
                }
                "products" -> {
                    val h = helper ?: return@setMethodCallHandler result.error("NOT_CONNECTED", "billing not connected", null)
                    val skus = call.argument<List<String>>("skus") ?: emptyList()
                    h.queryInventoryAsync(true, skus) { r, inv ->
                        if (!r.isSuccess || inv == null) result.error("QUERY_FAILED", r.message, null)
                        else result.success(skus.mapNotNull { s -> inv.getSkuDetails(s)?.let { d -> mapOf("sku" to s, "price" to d.price) } })
                    }
                }
                "purchase" -> {
                    val h = helper ?: return@setMethodCallHandler result.error("NOT_CONNECTED", "billing not connected", null)
                    val sku = call.argument<String>("sku")!!
                    h.launchPurchaseFlow(activity, sku, { r, purchase ->
                        when {
                            r.isSuccess && purchase != null -> {
                                remember(purchase)
                                result.success(mapOf("status" to "success", "sku" to purchase.sku, "token" to purchase.token, "order_id" to purchase.orderId))
                            }
                            r.response == -1005 -> result.success(mapOf("status" to "canceled")) // IABHELPER_USER_CANCELLED
                            else -> result.success(mapOf("status" to "error"))
                        }
                    }, null)
                }
                "restore" -> {
                    val h = helper ?: return@setMethodCallHandler result.error("NOT_CONNECTED", "billing not connected", null)
                    h.queryInventoryAsync(false, null) { r, inv ->
                        if (!r.isSuccess || inv == null) result.error("QUERY_FAILED", r.message, null)
                        else {
                            val all = inv.allPurchases
                            all.forEach { remember(it) }
                            result.success(all.map { mapOf("sku" to it.sku, "token" to it.token, "order_id" to it.orderId) })
                        }
                    }
                }
                "consume" -> {
                    val h = helper ?: return@setMethodCallHandler result.error("NOT_CONNECTED", "billing not connected", null)
                    val p = known[call.argument<String>("token")!!] ?: return@setMethodCallHandler result.success(false)
                    h.consumeAsync(p) { _, r -> if (r.isSuccess) result.success(true) else result.error("CONSUME_FAILED", r.message, null) }
                }
                else -> result.notImplemented()
            }
        }
    }
}
