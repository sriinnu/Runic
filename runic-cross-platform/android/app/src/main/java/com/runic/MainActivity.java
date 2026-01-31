/**
 * @file MainActivity.java
 * @description Main Android activity for React Native application.
 * Implements Material You theming and handles app lifecycle.
 */

package com.runic;

import android.os.Bundle;
import androidx.core.view.WindowCompat;
import com.facebook.react.ReactActivity;
import com.facebook.react.ReactActivityDelegate;
import com.facebook.react.defaults.DefaultNewArchitectureEntryPoint;
import com.facebook.react.defaults.DefaultReactActivityDelegate;

/**
 * Main activity that hosts the React Native application.
 * Enables edge-to-edge display and Material You theming.
 */
public class MainActivity extends ReactActivity {

  /**
   * Returns the name of the main component registered from JavaScript.
   * This is used to schedule rendering of the component.
   */
  @Override
  protected String getMainComponentName() {
    return "runic-cross-platform";
  }

  /**
   * Called when the activity is starting.
   * Sets up edge-to-edge display for Material You theming.
   *
   * @param savedInstanceState Bundle containing the activity's previously saved state
   */
  @Override
  protected void onCreate(Bundle savedInstanceState) {
    // Enable edge-to-edge display
    WindowCompat.setDecorFitsSystemWindows(getWindow(), false);

    super.onCreate(null);
  }

  /**
   * Returns the instance of the {@link ReactActivityDelegate}.
   * Enables the New Architecture if configured.
   */
  @Override
  protected ReactActivityDelegate createReactActivityDelegate() {
    return new DefaultReactActivityDelegate(
        this,
        getMainComponentName(),
        // Enable Fabric (New Architecture) if desired
        DefaultNewArchitectureEntryPoint.getFabricEnabled()
    );
  }
}
