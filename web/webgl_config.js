// Enhanced WebGL configuration for Chrome Canary compatibility
(function() {
  // This script addresses WebGL issues in Chrome Canary and other browsers

  // Log function that also updates the loading status if available
  function logWebGL(message) {
    console.log('[WebGL Config] ' + message);

    // Update loading status if available
    if (window.updateLoadingStatus) {
      window.updateLoadingStatus(message);
    }

    // Use the safe logger if available
    if (window.safeLogStage) {
      window.safeLogStage('[WebGL] ' + message);
      return;
    }

    // Fall back to flutterDebug if available
    if (window.flutterDebug && typeof window.flutterDebug.logStage === 'function') {
      try {
        window.flutterDebug.logStage('[WebGL] ' + message);
      } catch (e) {
        console.log('Error logging WebGL message to debug panel: ' + e.message);
      }
    }
  }

  // Check if we're running in a browser environment
  if (typeof window !== 'undefined') {
    // Detect browser type
    const isChrome = navigator.userAgent.indexOf('Chrome') > -1;
    const isCanary = isChrome && navigator.userAgent.indexOf('Chrome/') > -1 &&
                    parseInt(navigator.userAgent.match(/Chrome\/(\d+)/)[1], 10) >= 100;

    if (isCanary) {
      logWebGL('Chrome Canary detected. Applying special WebGL configuration.');
    }

    // Function to detect if WebGL is available
    function detectWebGL() {
      // Try to create a WebGL context
      try {
        const canvas = document.createElement('canvas');
        const hasWebGL1 = !!(
          window.WebGLRenderingContext &&
          (canvas.getContext('webgl') || canvas.getContext('experimental-webgl'))
        );

        const hasWebGL2 = !!(
          window.WebGL2RenderingContext &&
          canvas.getContext('webgl2')
        );

        if (hasWebGL2) {
          logWebGL('WebGL 2 is supported');
          return 2;
        } else if (hasWebGL1) {
          logWebGL('WebGL 1 is supported');
          return 1;
        } else {
          logWebGL('WebGL is not supported');
          return 0;
        }
      } catch (e) {
        logWebGL('Error detecting WebGL: ' + e.message);
        return 0;
      }
    }

    // Detect WebGL support
    const webGLVersion = detectWebGL();

    // Configure based on WebGL support
    if (webGLVersion === 0) {
      logWebGL('No WebGL support detected. Configuring for software rendering.');

      // Force software rendering if possible
      const softwareRenderingMeta = document.createElement('meta');
      softwareRenderingMeta.name = 'webgl-renderer';
      softwareRenderingMeta.content = 'software';
      document.head.appendChild(softwareRenderingMeta);
    } else {
      // For Chrome Canary, we need to ensure hardware acceleration is used
      if (isCanary) {
        logWebGL('Configuring Chrome Canary for hardware acceleration');

        // Add meta tags to force hardware acceleration
        const hardwareAccelMeta = document.createElement('meta');
        hardwareAccelMeta.name = 'hardware-acceleration';
        hardwareAccelMeta.content = 'force';
        document.head.appendChild(hardwareAccelMeta);
      }
    }

    // Intercept console warnings about SwiftShader
    const originalConsoleWarn = console.warn;
    console.warn = function(message) {
      // Check if the message is about SwiftShader or WebGL
      if (typeof message === 'string' &&
          (message.includes('SwiftShader') ||
           message.includes('software WebGL') ||
           message.includes('WebGL has been deprecated'))) {
        // Log it but don't show in console
        logWebGL('Suppressed warning: ' + message.substring(0, 100) + '...');
        return;
      }
      // Pass through all other warnings
      originalConsoleWarn.apply(console, arguments);
    };

    // Add a meta tag to indicate we're handling WebGL configuration
    const meta = document.createElement('meta');
    meta.name = 'webgl-renderer-config';
    meta.content = 'configured-enhanced';
    document.head.appendChild(meta);

    logWebGL('WebGL configuration complete');
  }
})();
