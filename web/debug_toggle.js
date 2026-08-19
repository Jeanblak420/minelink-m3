// Debug toggle script to control visibility of debug elements
(function() {
  // Wait for the DOM to be fully loaded
  window.addEventListener('DOMContentLoaded', function() {
    // Create a toggle button after a short delay to ensure Flutter has initialized
    setTimeout(createToggleButton, 2000);
  });

  function createToggleButton() {
    // Create the toggle button
    const toggleButton = document.createElement('button');
    toggleButton.id = 'debug-toggle-button';
    toggleButton.textContent = 'Toggle Debug Info';
    toggleButton.style.position = 'fixed';
    toggleButton.style.bottom = '20px';
    toggleButton.style.right = '20px';
    toggleButton.style.zIndex = '10000';
    toggleButton.style.padding = '8px 12px';
    toggleButton.style.backgroundColor = '#4285F4';
    toggleButton.style.color = 'white';
    toggleButton.style.border = 'none';
    toggleButton.style.borderRadius = '4px';
    toggleButton.style.boxShadow = '0 2px 5px rgba(0,0,0,0.3)';
    toggleButton.style.cursor = 'pointer';
    toggleButton.style.fontFamily = 'Arial, sans-serif';
    toggleButton.style.fontSize = '14px';
    toggleButton.style.display = 'none'; // Initially hidden until we confirm debug elements exist

    // Add hover effect
    toggleButton.onmouseover = function() {
      this.style.backgroundColor = '#3367D6';
    };
    toggleButton.onmouseout = function() {
      this.style.backgroundColor = '#4285F4';
    };

    // Add click handler
    toggleButton.onclick = toggleDebugElements;

    // Add to document
    document.body.appendChild(toggleButton);

    // Check if debug elements exist and show button if they do
    checkForDebugElements();
  }

  function checkForDebugElements() {
    // Elements to check for
    const debugElements = [
      document.getElementById('flutter-debug-info'),
      document.querySelector('flt-semantics-placeholder[role="button"][aria-live="polite"]'),
      document.querySelector('flt-announcement-host'),
      document.querySelector('flt-file-picker-inputs'),
      document.querySelector('flt-image-picker-inputs')
    ];

    // If any debug elements exist, show the toggle button
    const hasDebugElements = debugElements.some(el => el !== null);
    
    if (hasDebugElements) {
      const toggleButton = document.getElementById('debug-toggle-button');
      if (toggleButton) {
        toggleButton.style.display = 'block';
      }
    } else {
      // Check again after a delay
      setTimeout(checkForDebugElements, 2000);
    }
  }

  function toggleDebugElements() {
    // Toggle flutter-debug-info
    const debugInfo = document.getElementById('flutter-debug-info');
    if (debugInfo) {
      debugInfo.style.display = debugInfo.style.display === 'none' ? 'block' : 'none';
    }

    // Toggle accessibility placeholder
    const accessibilityPlaceholder = document.querySelector('flt-semantics-placeholder[role="button"][aria-live="polite"]');
    if (accessibilityPlaceholder) {
      accessibilityPlaceholder.style.display = accessibilityPlaceholder.style.display === 'none' ? 'block' : 'none';
    }

    // Toggle announcement host
    const announcementHost = document.querySelector('flt-announcement-host');
    if (announcementHost) {
      announcementHost.style.display = announcementHost.style.display === 'none' ? 'block' : 'none';
    }

    // Toggle file picker inputs
    const filePickerInputs = document.querySelector('flt-file-picker-inputs');
    if (filePickerInputs) {
      filePickerInputs.style.display = filePickerInputs.style.display === 'none' ? 'block' : 'none';
    }

    // Toggle image picker inputs
    const imagePickerInputs = document.querySelector('flt-image-picker-inputs');
    if (imagePickerInputs) {
      imagePickerInputs.style.display = imagePickerInputs.style.display === 'none' ? 'block' : 'none';
    }
  }

  // Initialize by hiding debug elements on page load
  window.addEventListener('load', function() {
    // Hide debug elements initially
    const debugInfo = document.getElementById('flutter-debug-info');
    if (debugInfo) {
      debugInfo.style.display = 'none';
    }

    const accessibilityPlaceholder = document.querySelector('flt-semantics-placeholder[role="button"][aria-live="polite"]');
    if (accessibilityPlaceholder) {
      accessibilityPlaceholder.style.display = 'none';
    }

    const announcementHost = document.querySelector('flt-announcement-host');
    if (announcementHost) {
      announcementHost.style.display = 'none';
    }
  });
})();
