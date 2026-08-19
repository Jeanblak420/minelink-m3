// Debug script to help identify loading issues in Chrome Canary
(function() {
  // Track loading stages
  const loadingStages = [];

  function logStage(stage) {
    console.log(`[Debug] ${stage}`);
    loadingStages.push({ stage, time: new Date().toISOString() });

    try {
      // Also display visually on page for debugging
      const debugDiv = document.getElementById('flutter-debug-info') || createDebugDiv();
      const stageElement = document.createElement('div');
      stageElement.textContent = `${new Date().toLocaleTimeString()} - ${stage}`;
      debugDiv.appendChild(stageElement);
    } catch (e) {
      console.log(`Error displaying debug message: ${e.message}`);
    }
  }

  // Process any early messages that were logged before this script loaded
  if (window._earlyDebugMessages && window._earlyDebugMessages.length > 0) {
    window._earlyDebugMessages.forEach(message => {
      logStage(`[Early] ${message}`);
    });
    window._earlyDebugMessages = [];
  }

  function createDebugDiv() {
    // Check if body exists before trying to append
    if (!document.body) {
      console.log('Document body not ready yet, debug div creation deferred');
      // Return a temporary object that can still accept appendChild
      return {
        appendChild: function(element) {
          // Store messages to add later when body is available
          if (!window._pendingDebugMessages) {
            window._pendingDebugMessages = [];
          }
          window._pendingDebugMessages.push(element.textContent);
        }
      };
    }

    // Check if the debug div already exists
    let debugDiv = document.getElementById('flutter-debug-info');
    if (debugDiv) {
      return debugDiv;
    }

    // Create the debug div
    debugDiv = document.createElement('div');
    debugDiv.id = 'flutter-debug-info';
    debugDiv.style.position = 'fixed';
    debugDiv.style.top = '10px';
    debugDiv.style.left = '10px';
    debugDiv.style.backgroundColor = 'rgba(0, 0, 0, 0.7)';
    debugDiv.style.color = 'white';
    debugDiv.style.padding = '10px';
    debugDiv.style.borderRadius = '5px';
    debugDiv.style.zIndex = '9999';
    debugDiv.style.maxHeight = '80vh';
    debugDiv.style.overflowY = 'auto';
    debugDiv.style.fontFamily = 'monospace';
    debugDiv.style.fontSize = '12px';

    const heading = document.createElement('h3');
    heading.textContent = 'Flutter Debug Info';
    heading.style.margin = '0 0 10px 0';
    debugDiv.appendChild(heading);

    // Add any pending messages
    if (window._pendingDebugMessages && window._pendingDebugMessages.length > 0) {
      window._pendingDebugMessages.forEach(message => {
        const msgElement = document.createElement('div');
        msgElement.textContent = message;
        debugDiv.appendChild(msgElement);
      });
      window._pendingDebugMessages = [];
    }

    document.body.appendChild(debugDiv);
    return debugDiv;
  }

  // Log initial stage
  window.addEventListener('DOMContentLoaded', function() {
    logStage('DOMContentLoaded event fired');

    // Check if body is empty
    if (document.body.children.length <= 2) { // Accounting for our debug div
      logStage('WARNING: Body is nearly empty, Flutter might not be initializing');
    }
  });

  // Monitor script loading
  const originalCreateElement = document.createElement;
  document.createElement = function(tagName) {
    const element = originalCreateElement.call(document, tagName);

    if (tagName.toLowerCase() === 'script') {
      const originalSetAttribute = element.setAttribute;
      element.setAttribute = function(name, value) {
        if (name === 'src') {
          logStage(`Loading script: ${value}`);

          // Add error handling for script loading
          element.addEventListener('error', function() {
            logStage(`ERROR: Failed to load script: ${value}`);
          });

          element.addEventListener('load', function() {
            logStage(`Successfully loaded script: ${value}`);
          });
        }
        return originalSetAttribute.call(this, name, value);
      };
    }

    return element;
  };

  // Monitor for Flutter initialization
  window.addEventListener('load', function() {
    logStage('Window load event fired');

    // Check for Flutter's global objects
    setTimeout(function checkFlutter() {
      if (window._flutter) {
        logStage('Flutter engine initialized (_flutter object found)');
      } else {
        logStage('WARNING: Flutter engine not initialized after 2 seconds');

        // Check if main.dart.js was loaded
        const scripts = document.getElementsByTagName('script');
        let mainDartFound = false;

        for (let i = 0; i < scripts.length; i++) {
          if (scripts[i].src && scripts[i].src.includes('main.dart.js')) {
            mainDartFound = true;
            break;
          }
        }

        if (!mainDartFound) {
          logStage('ERROR: main.dart.js was not loaded');
        }
      }
    }, 2000);
  });

  // Expose debug functions globally
  window.flutterDebug = {
    getLoadingStages: function() {
      return loadingStages;
    },
    logStage: logStage
  };

  logStage('Debug loader initialized');
})();
