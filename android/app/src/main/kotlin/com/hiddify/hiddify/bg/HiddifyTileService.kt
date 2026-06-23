package com.hiddify.hiddify.bg

import androidx.wear.protolayout.ActionBuilders
import androidx.wear.protolayout.ColorBuilders
import androidx.wear.protolayout.ModifiersBuilders
import androidx.wear.protolayout.ResourceBuilders
import androidx.wear.protolayout.TimelineBuilders
import androidx.wear.protolayout.material.CompactChip
import androidx.wear.protolayout.material.Text
import androidx.wear.protolayout.material.Typography
import androidx.wear.protolayout.material.layouts.PrimaryLayout
import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.TileBuilders
import androidx.wear.tiles.TileService
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

private const val RESOURCES_VERSION = "1"

/// Wear OS quick-toggle tile. Tapping it opens the app with a "toggle" action,
/// which connects/disconnects the local proxy. State label is read from the
/// Flutter shared preferences the app writes on connection changes.
class HiddifyTileService : TileService() {
    override fun onTileRequest(
        requestParams: RequestBuilders.TileRequest,
    ): ListenableFuture<TileBuilders.Tile> {
        val connected = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            .getBoolean("flutter.hiddify_wear_connected", false)

        val clickable = ModifiersBuilders.Clickable.Builder()
            .setId("toggle")
            .setOnClick(
                ActionBuilders.LaunchAction.Builder()
                    .setAndroidActivity(
                        ActionBuilders.AndroidActivity.Builder()
                            .setPackageName(packageName)
                            .setClassName("com.hiddify.hiddify.MainActivity")
                            .addKeyToExtraMapping(
                                "hiddify_tile_action",
                                ActionBuilders.AndroidStringExtra.Builder().setValue("toggle").build(),
                            )
                            .build(),
                    )
                    .build(),
            )
            .build()

        val deviceParams = requestParams.deviceConfiguration

        val layout = PrimaryLayout.Builder(deviceParams)
            .setContent(
                Text.Builder(this, if (connected) "VPN On" else "VPN Off")
                    .setTypography(Typography.TYPOGRAPHY_TITLE2)
                    .setColor(ColorBuilders.argb(0xFFFFFFFF.toInt()))
                    .build(),
            )
            .setPrimaryChipContent(
                CompactChip.Builder(
                    this,
                    if (connected) "Disconnect" else "Connect",
                    clickable,
                    deviceParams,
                ).build(),
            )
            .build()

        val tile = TileBuilders.Tile.Builder()
            .setResourcesVersion(RESOURCES_VERSION)
            .setTileTimeline(TimelineBuilders.Timeline.fromLayoutElement(layout))
            .build()
        return Futures.immediateFuture(tile)
    }

    override fun onTileResourcesRequest(
        requestParams: RequestBuilders.ResourcesRequest,
    ): ListenableFuture<ResourceBuilders.Resources> {
        return Futures.immediateFuture(
            ResourceBuilders.Resources.Builder().setVersion(RESOURCES_VERSION).build(),
        )
    }
}
