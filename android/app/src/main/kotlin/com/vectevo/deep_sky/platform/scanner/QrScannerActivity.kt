package com.vectevo.deep_sky.platform.scanner

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.zxing.BarcodeFormat
import com.google.zxing.BinaryBitmap
import com.google.zxing.DecodeHintType
import com.google.zxing.MultiFormatReader
import com.google.zxing.NotFoundException
import com.google.zxing.PlanarYUVLuminanceSource
import com.google.zxing.common.HybridBinarizer
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Full-screen CameraX + ZXing QR code scanner activity (`S1-D06`, `S1-D10`).
 * Uses Apache-2.0 CameraX and ZXing Core with zero proprietary Play Services dependencies.
 */
class QrScannerActivity : ComponentActivity() {
    companion object {
        const val EXTRA_TITLE = "title"
        const val EXTRA_HINT = "hint"
        const val EXTRA_CANCEL_LABEL = "cancelLabel"
        const val EXTRA_RESULT_PAYLOAD = "qrPayload"
        const val EXTRA_ERROR_CODE = "errorCode"
        private const val REQ_CAMERA_PERMISSION = 4103
    }

    private lateinit var previewView: PreviewView
    private lateinit var statusView: TextView
    private lateinit var cameraExecutor: ExecutorService
    private val handledResult = AtomicBoolean(false)

    private val qrReader = MultiFormatReader().apply {
        setHints(
            mapOf(
                DecodeHintType.POSSIBLE_FORMATS to listOf(BarcodeFormat.QR_CODE),
                DecodeHintType.TRY_HARDER to true,
            ),
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        cameraExecutor = Executors.newSingleThreadExecutor()
        buildScannerUi()

        if (hasCameraPermission()) {
            startCamera()
        } else {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.CAMERA),
                REQ_CAMERA_PERMISSION,
            )
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        cameraExecutor.shutdown()
    }

    @Suppress("DEPRECATION")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQ_CAMERA_PERMISSION) {
            return
        }
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        if (granted) {
            startCamera()
        } else {
            setResult(
                Activity.RESULT_CANCELED,
                Intent().putExtra(EXTRA_ERROR_CODE, "camera_permission_denied"),
            )
            finish()
        }
    }

    private fun hasCameraPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.CAMERA,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun buildScannerUi() {
        val density = resources.displayMetrics.density
        fun dp(value: Int): Int = (value * density).toInt()

        val title = intent.getStringExtra(EXTRA_TITLE)?.takeIf { it.isNotBlank() } ?: "Inquadra codice QR"
        val hint = intent.getStringExtra(EXTRA_HINT)?.takeIf { it.isNotBlank() }
            ?: "Inquadra il QR mostrato dal tuo partner"
        val cancelLabel = intent.getStringExtra(EXTRA_CANCEL_LABEL)?.takeIf { it.isNotBlank() } ?: "Annulla"

        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#190F24"))
        }

        previewView = PreviewView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            )
        }
        root.addView(previewView)

        val reticle = View(this).apply {
            layoutParams = FrameLayout.LayoutParams(dp(240), dp(240), Gravity.CENTER)
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(24).toFloat()
                setColor(Color.TRANSPARENT)
                setStroke(dp(3), Color.parseColor("#FFAFD3"))
            }
        }
        root.addView(reticle)

        val topBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(20), dp(42), dp(20), dp(16))
            setBackgroundColor(Color.parseColor("#99190F24"))
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.TOP,
            )
        }

        val titleView = TextView(this).apply {
            text = title
            setTextColor(Color.parseColor("#EEDCFA"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }

        val closeButton = Button(this).apply {
            text = cancelLabel
            setTextColor(Color.parseColor("#EEDCFA"))
            isAllCaps = false
            background = GradientDrawable().apply {
                cornerRadius = dp(99).toFloat()
                setColor(Color.parseColor("#30253C"))
            }
            setPadding(dp(16), dp(8), dp(16), dp(8))
            setOnClickListener {
                setResult(Activity.RESULT_CANCELED)
                finish()
            }
        }
        topBar.addView(titleView)
        topBar.addView(closeButton)
        root.addView(topBar)

        statusView = TextView(this).apply {
            text = hint
            gravity = Gravity.CENTER
            setTextColor(Color.parseColor("#FEF3C7"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            setPadding(dp(24), dp(18), dp(24), dp(36))
            setBackgroundColor(Color.parseColor("#B3190F24"))
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM,
            )
        }
        root.addView(statusView)

        setContentView(root)
    }

    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
        cameraProviderFuture.addListener(
            {
                val cameraProvider = try {
                    cameraProviderFuture.get()
                } catch (_: Exception) {
                    finishWithError("camera_unavailable")
                    return@addListener
                }

                val preview = Preview.Builder().build().apply {
                    surfaceProvider = previewView.surfaceProvider
                }

                val analysis = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()
                    .apply {
                        setAnalyzer(cameraExecutor) { image ->
                            analyzeFrame(image)
                        }
                    }

                try {
                    cameraProvider.unbindAll()
                    cameraProvider.bindToLifecycle(
                        this,
                        CameraSelector.DEFAULT_BACK_CAMERA,
                        preview,
                        analysis,
                    )
                } catch (_: Exception) {
                    finishWithError("camera_unavailable")
                }
            },
            ContextCompat.getMainExecutor(this),
        )
    }

    private fun analyzeFrame(image: ImageProxy) {
        if (handledResult.get()) {
            image.close()
            return
        }
        try {
            val yPlane = image.planes.firstOrNull() ?: return
            val buffer = yPlane.buffer
            val data = ByteArray(buffer.remaining())
            buffer.get(data)

            val width = yPlane.rowStride
            val height = image.height
            val cropWidth = image.width.coerceAtMost(width)

            val source = PlanarYUVLuminanceSource(
                data,
                width,
                height,
                0,
                0,
                cropWidth,
                height,
                false,
            )
            val bitmap = BinaryBitmap(HybridBinarizer(source))
            val decoded = try {
                qrReader.decodeWithState(bitmap)
            } catch (_: NotFoundException) {
                try {
                    qrReader.decodeWithState(
                        BinaryBitmap(HybridBinarizer(source.invert())),
                    )
                } catch (_: Exception) {
                    null
                }
            } finally {
                qrReader.reset()
            }

            val rawText = decoded?.text?.trim()
            if (!rawText.isNullOrEmpty() && handledResult.compareAndSet(false, true)) {
                runOnUiThread {
                    setResult(
                        Activity.RESULT_OK,
                        Intent().putExtra(EXTRA_RESULT_PAYLOAD, rawText),
                    )
                    finish()
                }
            }
        } catch (_: Exception) {
            // Keep scanning subsequent camera frames calmly.
        } finally {
            image.close()
        }
    }

    private fun finishWithError(code: String) {
        if (!isFinishing) {
            setResult(Activity.RESULT_CANCELED, Intent().putExtra(EXTRA_ERROR_CODE, code))
            finish()
        }
    }
}
