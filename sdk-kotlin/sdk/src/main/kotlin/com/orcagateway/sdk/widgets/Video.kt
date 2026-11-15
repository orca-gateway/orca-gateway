package com.orcagateway.sdk.widgets

import android.content.Context
import android.graphics.Matrix
import android.graphics.SurfaceTexture
import android.media.MediaPlayer
import android.view.Surface
import android.view.TextureView
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.client.ImageLoader
import com.orcagateway.sdk.style.Props

/**
 * `Video` (engine/src/components/primitive/video.ts), as Swift's
 * VideoNodeView: a network video (`src`, mp4 or HLS) in a `width` by
 * `height` box, fitted by `fit` (`cover` by default, else contained). With
 * `autoplay` (default) it plays while at least `visibleFraction` (default
 * 0.5) of it is inside the window and the scroll views around it, and
 * pauses when it scrolls away; it is released when it leaves the
 * composition. `muted` and `loop` default to true, as in a feed. `poster`
 * is drawn until the first frame is rendered.
 *
 * Built on the platform's MediaPlayer and a TextureView, so the SDK takes no
 * media dependency.
 */
@Composable
internal fun VideoWidget(node: ResolvedNode, modifier: Modifier) {
    val src = Props.text(node["src"])
    val poster = node["poster"]?.stringValue
    val cover = (node["fit"]?.stringValue ?: "cover") == "cover"
    val autoplay = node["autoplay"]?.boolValue ?: true
    val threshold = node["visibleFraction"]?.doubleValue ?: 0.5
    val muted = node["muted"]?.boolValue ?: true
    val loop = node["loop"]?.boolValue ?: true

    var box = modifier
    Props.length(node["width"])?.let { box = box.width(it) }
    Props.length(node["height"])?.let { box = box.height(it) }

    var visible by remember { mutableStateOf(false) }
    var rendering by remember(src) { mutableStateOf(false) }
    var posterBitmap by remember(poster) { mutableStateOf<ImageBitmap?>(null) }
    LaunchedEffect(poster) { posterBitmap = poster?.let { ImageLoader.shared.load(it) } }

    val context = LocalContext.current
    val player = remember(src) { VideoSurface(context, src) { rendering = true } }
    DisposableEffect(player) { onDispose { player.release() } }
    player.configure(cover = cover, muted = muted, loop = loop, playing = autoplay && visible)

    Box(
        box
            .clipToBounds()
            .background(Color.Black)
            .onGloballyPositioned { coords ->
                val area = coords.size.width.toFloat() * coords.size.height
                val shown = coords.boundsInWindow()
                val fraction = if (area <= 0f) 0f else (shown.width * shown.height) / area
                visible = fraction >= threshold
            },
    ) {
        AndroidView(factory = { player.view }, modifier = Modifier.fillMaxSize())
        val image = posterBitmap
        if (!rendering && image != null) {
            Image(image, contentDescription = null, modifier = Modifier.fillMaxSize(), contentScale = imageFit(node["fit"]))
        }
    }
}

/** One MediaPlayer drawing into one TextureView, scaled to fill or fit it. */
private class VideoSurface(context: Context, private val src: String, private val onFirstFrame: () -> Unit) :
    TextureView.SurfaceTextureListener {
    val view = TextureView(context).also { it.surfaceTextureListener = this }
    private var player: MediaPlayer? = null
    private var surface: Surface? = null
    private var prepared = false
    private var cover = true
    private var muted = true
    private var loop = true
    private var playing = false
    private var videoWidth = 0
    private var videoHeight = 0

    fun configure(cover: Boolean, muted: Boolean, loop: Boolean, playing: Boolean) {
        this.cover = cover
        this.muted = muted
        this.loop = loop
        this.playing = playing
        apply()
    }

    private fun apply() {
        val p = player ?: return
        if (!prepared) return
        p.isLooping = loop
        val volume = if (muted) 0f else 1f
        p.setVolume(volume, volume)
        if (playing && !p.isPlaying) p.start()
        if (!playing && p.isPlaying) p.pause()
        scale()
    }

    private fun open(texture: SurfaceTexture) {
        if (!src.startsWith("http://") && !src.startsWith("https://")) return
        val s = Surface(texture)
        surface = s
        player = MediaPlayer().apply {
            setSurface(s)
            setOnPreparedListener {
                prepared = true
                this@VideoSurface.apply()
            }
            setOnVideoSizeChangedListener { _, w, h ->
                this@VideoSurface.videoWidth = w
                this@VideoSurface.videoHeight = h
                scale()
            }
            setOnInfoListener { _, what, _ ->
                if (what == MediaPlayer.MEDIA_INFO_VIDEO_RENDERING_START) onFirstFrame()
                false
            }
            setOnErrorListener { _, _, _ -> true }
            try {
                setDataSource(src)
                prepareAsync()
            } catch (_: Exception) {
                // A bad URL leaves the poster up, as a failed AVPlayer item does.
            }
        }
    }

    /** Centre-crop (cover) or centre-fit the video in the view. */
    private fun scale() {
        val vw = view.width.toFloat()
        val vh = view.height.toFloat()
        if (vw <= 0f || vh <= 0f || videoWidth <= 0 || videoHeight <= 0) return
        val sx = videoWidth / vw
        val sy = videoHeight / vh
        val k = if (cover) 1f / minOf(sx, sy) else 1f / maxOf(sx, sy)
        val matrix = Matrix()
        matrix.setScale(sx * k, sy * k, vw / 2, vh / 2)
        view.setTransform(matrix)
    }

    fun release() {
        player?.release()
        player = null
        prepared = false
        surface?.release()
        surface = null
    }

    override fun onSurfaceTextureAvailable(surface: SurfaceTexture, width: Int, height: Int) = open(surface)

    override fun onSurfaceTextureSizeChanged(surface: SurfaceTexture, width: Int, height: Int) = scale()

    override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean {
        release()
        return true
    }

    override fun onSurfaceTextureUpdated(surface: SurfaceTexture) = Unit
}
