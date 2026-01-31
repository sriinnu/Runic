/**
 * @file MainApplication.java
 * @description Main Android application class for React Native.
 * Configures React Native packages and initializes the application.
 */

package com.runic;

import android.app.Application;
import com.facebook.react.PackageList;
import com.facebook.react.ReactApplication;
import com.facebook.react.ReactNativeHost;
import com.facebook.react.ReactPackage;
import com.facebook.react.defaults.DefaultNewArchitectureEntryPoint;
import com.facebook.react.defaults.DefaultReactNativeHost;
import com.facebook.soloader.SoLoader;
import java.util.List;

/**
 * Main application class that initializes React Native.
 * Configures packages, enables New Architecture, and handles app setup.
 */
public class MainApplication extends Application implements ReactApplication {

  /**
   * React Native host configuration.
   * Defines app settings and package list.
   */
  private final ReactNativeHost mReactNativeHost =
      new DefaultReactNativeHost(this) {
        @Override
        public boolean getUseDeveloperSupport() {
          return BuildConfig.DEBUG;
        }

        /**
         * Returns list of all React Native packages.
         * Includes auto-linked packages from PackageList.
         */
        @Override
        protected List<ReactPackage> getPackages() {
          List<ReactPackage> packages = new PackageList(this).getPackages();
          // Add custom packages here if needed
          // packages.add(new MyCustomPackage());
          return packages;
        }

        @Override
        protected String getJSMainModuleName() {
          return "index";
        }

        @Override
        protected boolean isNewArchEnabled() {
          return BuildConfig.IS_NEW_ARCHITECTURE_ENABLED;
        }

        @Override
        protected Boolean isHermesEnabled() {
          return BuildConfig.IS_HERMES_ENABLED;
        }
      };

  @Override
  public ReactNativeHost getReactNativeHost() {
    return mReactNativeHost;
  }

  /**
   * Called when the application is starting.
   * Initializes React Native and SoLoader.
   */
  @Override
  public void onCreate() {
    super.onCreate();

    // Initialize SoLoader for loading native libraries
    SoLoader.init(this, /* native exopackage */ false);

    // Initialize New Architecture if enabled
    if (BuildConfig.IS_NEW_ARCHITECTURE_ENABLED) {
      DefaultNewArchitectureEntryPoint.load();
    }

    // Initialize notification channels (Android 8.0+)
    NotificationChannelManager.createNotificationChannels(this);
  }
}
