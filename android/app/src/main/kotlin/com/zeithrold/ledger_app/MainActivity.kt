package com.zeithrold.ledger_app

import com.clerk.api.Clerk
import com.clerk.api.ClerkConfigurationOptions
import com.clerk.api.hostedauth.HostedAuthCancellationException
import com.clerk.api.network.serialization.ClerkResult
import com.clerk.api.session.GetTokenOptions
import com.clerk.api.session.Session
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*

class MainActivity : FlutterActivity() {
    private val authScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var sink: EventChannel.EventSink? = null
    private var observer: Job? = null
    private var revision = 0
    private var signingIn = false

    private fun snapshot(): Map<String, Any?> {
        revision += 1
        val session = Clerk.session
        return mapOf("revision" to revision,
            "active" to (session?.status == Session.SessionStatus.ACTIVE),
            "sessionId" to session?.id, "userId" to session?.user?.id)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        EventChannel(messenger, "ledger/auth/events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                sink = events
                if (Clerk.isInitialized.value) events.success(snapshot())
            }
            override fun onCancel(arguments: Any?) { sink = null }
        })
        MethodChannel(messenger, "ledger/auth").setMethodCallHandler { call, result ->
            authScope.launch {
                try {
                    when (call.method) {
                        "initialize" -> {
                            val key = call.argument<String>("publishableKey") ?: error("configuration")
                            Clerk.initialize(this@MainActivity, key,
                                ClerkConfigurationOptions(telemetryEnabled = false))
                            withTimeout(20_000) {
                                combine(Clerk.isInitialized, Clerk.initializationError) { ready, failure ->
                                    if (failure != null) error("initialization")
                                    ready
                                }.first { it }
                            }
                            if (observer == null) observer = authScope.launch {
                                Clerk.sessionFlow.collect { sink?.success(snapshot()) }
                            }
                            result.success(snapshot())
                        }
                        "signIn" -> {
                            check(Clerk.isInitialized.value && !signingIn)
                            signingIn = true
                            try {
                                when (val response = Clerk.auth.startHostedAuth()) {
                                    is ClerkResult.Success -> result.success(snapshot())
                                    is ClerkResult.Failure -> result.error(
                                        if (response.throwable is HostedAuthCancellationException) "cancelled" else "authentication",
                                        null, null)
                                }
                            } finally { signingIn = false }
                        }
                        "token" -> {
                            val session = Clerk.session
                            check(session?.status == Session.SessionStatus.ACTIVE)
                            when (val response = Clerk.auth.getToken(GetTokenOptions(
                                skipCache = call.argument<Boolean>("refresh") == true))) {
                                is ClerkResult.Success -> {
                                    check(session?.id == Clerk.session?.id)
                                    result.success(response.value)
                                }
                                is ClerkResult.Failure -> result.error("authentication", null, null)
                            }
                        }
                        "signOut" -> when (Clerk.auth.signOut()) {
                            is ClerkResult.Success -> result.success(snapshot())
                            is ClerkResult.Failure -> result.error("authentication", null, null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (_: Exception) {
                    result.error("authentication", null, null)
                }
            }
        }
    }

    override fun onDestroy() {
        authScope.cancel()
        super.onDestroy()
    }
}
