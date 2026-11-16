package com.orcagateway.plugins.videoplayer

import android.graphics.SurfaceTexture
import android.view.Surface
import android.view.TextureView
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilder

/** The test tag of the loading circle, drawn until the video is ready. */
internal const val LOADING_TAG: String = "videoPlayer.loading"

/** The test tag of the video (the TextureView), drawn once it is ready. */
internal const val VIDEO_TAG: String = "videoPlayer.video"

/** The test tag of the overlay's play button, drawn with showControls while not playing. */
internal const val PLAY_BUTTON_TAG: String = "videoPlayer.play"

/**
 * Flutter's `_buildVideoPlayer`: url defaults to "", autoPlay and looping to
 * false, showControls to true, aspectRatio to the video's, playerId to the
 * node's id.
 */
internal fun videoPlayerBuilder(plugin: VideoPlayerPlugin): WidgetBuilder = { node, model, modifier ->
    val props = VideoPlayerProps(node)
    val playerId = props.playerId ?: node.id
    // Flutter's ValueKey('video_player_$playerId'): another id is another view.
    key(playerId) {
        VideoPlayerView(
            plugin = plugin,
            playerId = playerId,
            url = props.url ?: "",
            autoPlay = props.autoPlay ?: false,
            looping = props.looping ?: false,
            showControls = props.showControls ?: true,
            aspectRatio = props.aspectRatio,
            node = node,
            model = model,
            modifier = modifier,
        )
    }
}

/**
 * Flutter's `_OrcaVideoPlayer`: a player for the url (a new url, a new
 * player), registered under playerId once ready and removed when the view
 * leaves or the url changes. Fires the node's onProgress, onComplete and
 * onError from the player's updates, and onPlay and onPause from the
 * overlay tap only.
 */
@Composable
private fun VideoPlayerView(
    plugin: VideoPlayerPlugin,
    playerId: String,
    url: String,
    autoPlay: Boolean,
    looping: Boolean,
    showControls: Boolean,
    aspectRatio: Double?,
    node: ResolvedNode,
    model: OrcaPageModel,
    modifier: Modifier,
) {
    val controller = remember(plugin, url) { plugin.controller(url, looping) }
    var initialized by remember(controller) { mutableStateOf(false) }
    var hasError by remember(controller) { mutableStateOf(false) }
    val currentNode by rememberUpdatedState(node)
    val currentModel by rememberUpdatedState(model)
    val currentAutoPlay by rememberUpdatedState(autoPlay)

    DisposableEffect(controller) {
        // Flutter's `_completed`: onComplete once per reaching the end.
        var completed = false
        val listener: () -> Unit = {
            val value = controller.value
            if (value.isPlaying && value.durationMs > 0) {
                currentModel.fire(
                    VideoPlayerProps.Triggers.onProgress,
                    on = currentNode,
                    eventData = mapOf(
                        "position" to JsonValue.Int(value.positionMs),
                        "duration" to JsonValue.Int(value.durationMs),
                        "fraction" to JsonValue.Double(value.positionMs.toDouble() / value.durationMs),
                    ),
                )
            }
            if (value.positionMs >= value.durationMs && value.durationMs > 0 && !completed) {
                completed = true
                currentModel.fire(VideoPlayerProps.Triggers.onComplete, on = currentNode)
            } else if (value.positionMs < value.durationMs) {
                completed = false
            }
        }
        controller.addListener(listener)
        controller.initialize(
            onReady = {
                initialized = true
                plugin.players[playerId] = controller
                if (currentAutoPlay) controller.play()
            },
            onError = { message ->
                hasError = true
                currentModel.fire(
                    VideoPlayerProps.Triggers.onError,
                    on = currentNode,
                    eventData = mapOf("message" to JsonValue.String(message)),
                )
            },
        )
        onDispose {
            plugin.players.remove(playerId)
            controller.removeListener(listener)
            controller.dispose()
        }
    }

    if (hasError) {
        Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text("Video failed to load", fontSize = 14.sp)
        }
        return
    }
    if (!initialized) {
        Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Box(Modifier.size(32.dp).background(Color(0x33000000), CircleShape).testTag(LOADING_TAG))
        }
        return
    }

    val value = controller.value
    // Compose draws no ratio that is not positive (Flutter asserts): the video's own then.
    val ratio = aspectRatio?.toFloat()?.takeIf { it > 0f && it.isFinite() } ?: value.aspectRatio
    if (!showControls) {
        VideoSurface(controller, modifier.aspectRatio(ratio))
        return
    }

    val toggle: () -> Unit = {
        if (controller.value.isPlaying) {
            controller.pause()
            currentModel.fire(VideoPlayerProps.Triggers.onPause, on = currentNode)
        } else {
            controller.play()
            currentModel.fire(VideoPlayerProps.Triggers.onPlay, on = currentNode)
        }
    }
    Box(modifier.clickable(interactionSource = null, indication = null, onClick = toggle), contentAlignment = Alignment.Center) {
        VideoSurface(controller, Modifier.aspectRatio(ratio))
        if (!value.isPlaying) {
            Box(
                Modifier.size(56.dp).background(Color(0x99000000), CircleShape).testTag(PLAY_BUTTON_TAG),
                contentAlignment = Alignment.Center,
            ) {
                Text("▶", color = Color.White, fontSize = 24.sp, modifier = Modifier.padding(start = 4.dp))
            }
        }
    }
}

/** The video: a TextureView the player draws into, stretched to the box as Flutter's Texture is. */
@Composable
private fun VideoSurface(controller: VideoController, modifier: Modifier) {
    AndroidView(
        factory = { context -> TextureView(context).also { it.surfaceTextureListener = SurfaceBridge(controller) } },
        modifier = modifier.testTag(VIDEO_TAG),
    )
}

/** Hands the TextureView's surface to the player while it exists. */
private class SurfaceBridge(private val controller: VideoController) : TextureView.SurfaceTextureListener {
    private var surface: Surface? = null

    override fun onSurfaceTextureAvailable(texture: SurfaceTexture, width: Int, height: Int) {
        val surface = Surface(texture)
        this.surface = surface
        controller.setSurface(surface)
    }

    override fun onSurfaceTextureSizeChanged(texture: SurfaceTexture, width: Int, height: Int) = Unit

    override fun onSurfaceTextureDestroyed(texture: SurfaceTexture): Boolean {
        controller.setSurface(null)
        surface?.release()
        surface = null
        return true
    }

    override fun onSurfaceTextureUpdated(texture: SurfaceTexture) = Unit
}
