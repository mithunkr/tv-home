package com.mihir.tvhome;

import android.accessibilityservice.AccessibilityService;
import android.content.Intent;
import android.provider.Settings;
import android.util.Log;
import android.view.KeyEvent;
import android.view.accessibility.AccessibilityEvent;

/**
 * Handles the remote buttons that TCL's system code leaves to the stock launcher, which has to stay
 * disabled because it outranks any other home app. Buttons not listed here (Disney+, Movies, TCL Channel)
 * are opened by the system directly.
 */
public class AppKeyService extends AccessibilityService {
    // Key codes, from /tclconfig/tvcust/aio_resources/resource/common_overseas/input_key/shortcutkey.tkl
    private static final int KEY_SETTINGS = KeyEvent.KEYCODE_NOTIFICATION; // 83
    private static final int KEY_YOUTUBE = KeyEvent.KEYCODE_BUTTON_3;      // 190
    private static final int TCL_NETFLIX = 4062;
    private static final int TCL_PRIMEVIDEO = 4099;

    @Override
    protected boolean onKeyEvent(KeyEvent event) {
        Intent launch = intentFor(event.getKeyCode());
        if (launch == null) return false;
        if (event.getAction() == KeyEvent.ACTION_DOWN && event.getRepeatCount() == 0) {
            Log.i("tvhome", "app key " + event.getKeyCode() + " -> " + launch);
            startActivity(launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        }
        return true;
    }

    /** Returns null for other keys and for apps that aren't installed, so the key carries on as normal. */
    private Intent intentFor(int keyCode) {
        switch (keyCode) {
            case KEY_SETTINGS: return new Intent(Settings.ACTION_SETTINGS);
            case KEY_YOUTUBE: return appIntent("com.google.android.youtube.tv");
            case TCL_NETFLIX: return appIntent("com.netflix.ninja");
            case TCL_PRIMEVIDEO: return appIntent("com.amazon.amazonvideo.livingroom");
            default: return null;
        }
    }

    private Intent appIntent(String pkg) {
        return getPackageManager().getLeanbackLaunchIntentForPackage(pkg);
    }

    @Override public void onAccessibilityEvent(AccessibilityEvent event) {}
    @Override public void onInterrupt() {}
}
