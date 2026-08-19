// Handle browser events to manage session state
(function() {
  const SESSION_EXPIRED_EVENT = 'mineral-guide-session-expired';
  const REDIRECT_TO_LOGIN_KEY = 'redirect_to_login';
  const FORCE_LOGIN_REDIRECT_KEY = 'force_login_redirect';
  const FLUTTER_BRIDGE_READY_KEY = 'flutter_session_bridge_ready';

  // Flag to track if the page is being unloaded
  let isUnloading = false;

  function notifyFlutterSessionExpired() {
    window.dispatchEvent(new CustomEvent(SESSION_EXPIRED_EVENT));
  }

  // Function to clear session data - only used for explicit logout
  function clearSessionOnExit() {
    try {
      // Only proceed if we're not already handling an unload
      if (!isUnloading) {
        isUnloading = true;
        console.log('Explicit logout requested - clearing session data');

        // Get the Supabase client from Flutter
        const supabase = window.supabaseClient;

        // If we have access to the Supabase client, clear the session
        if (supabase && typeof supabase.clearSession === 'function') {
          console.log('Clearing session data via Supabase client');
          supabase.clearSession();
        }

        // Clear app-specific cache items but preserve Supabase auth tokens
        // This allows for explicit logout but doesn't interfere with normal page refreshes
        console.log('Clearing app-specific cache items');
        Object.keys(localStorage).forEach(key => {
          // Clear only app-specific cache items
          if (key.includes('company_data_') ||
              key.includes('employee_data_') ||
              key.includes('company_employees') ||
              key.includes('available_companies')) {
            console.log(`Removing app cache item: ${key}`);
            localStorage.removeItem(key);
          }
        });

        // Set a flag in sessionStorage to indicate explicit logout
        sessionStorage.setItem(FORCE_LOGIN_REDIRECT_KEY, 'true');
        sessionStorage.setItem(REDIRECT_TO_LOGIN_KEY, '/login');
      }
    } catch (e) {
      console.error('Error during explicit logout:', e);
    } finally {
      isUnloading = false; // Reset the flag
    }
  }

  // Handle page visibility changes
  document.addEventListener('visibilitychange', function() {
    if (document.visibilityState === 'hidden') {
      // Page is hidden (user switched tabs, minimized window, etc.)
      sessionStorage.setItem('page_hidden_at', Date.now().toString());
    } else if (document.visibilityState === 'visible') {
      // Page is visible again
      const hiddenAt = sessionStorage.getItem('page_hidden_at');
      if (hiddenAt) {
        const hiddenTime = parseInt(hiddenAt, 10);
        const visibleAgainTime = Date.now();
        const hiddenDuration = visibleAgainTime - hiddenTime;

        // If the page was hidden for more than 30 minutes, redirect to login
        if (hiddenDuration > 30 * 60 * 1000) { // 30 minutes in milliseconds
          console.log('Page was hidden for too long, redirecting to login');
          sessionStorage.setItem(FORCE_LOGIN_REDIRECT_KEY, 'true');
          sessionStorage.setItem(REDIRECT_TO_LOGIN_KEY, '/login');
          notifyFlutterSessionExpired();

          if (!sessionStorage.getItem(FLUTTER_BRIDGE_READY_KEY)) {
            window.location.href = '/login';
          }
        }
      }
    }
  });

  // Handle page unload (browser close, navigate away)
  // We're removing the beforeunload handler to prevent clearing session on page refresh
  // This will allow the session to persist when the user refreshes the page

  // Instead, we'll only clear the session when the user explicitly logs out
  // or when the session expires

  // Check if the app was previously closed
  window.addEventListener('DOMContentLoaded', function() {
    const forceLoginRedirect = sessionStorage.getItem(FORCE_LOGIN_REDIRECT_KEY);

    // Only redirect if explicitly forced (not on normal page refresh/reload)
    if (forceLoginRedirect === 'true') {
      console.log('Login redirect was forced');
      sessionStorage.removeItem(FORCE_LOGIN_REDIRECT_KEY);

      // Set a flag that Flutter can check to redirect to login
      if (!sessionStorage.getItem(REDIRECT_TO_LOGIN_KEY)) {
        sessionStorage.setItem(REDIRECT_TO_LOGIN_KEY, '/login');
      }
    } else {
      // Remove any existing redirect flag to ensure we don't redirect unnecessarily
      sessionStorage.removeItem(REDIRECT_TO_LOGIN_KEY);
      console.log('Normal page load - maintaining session');
    }

    // Always clear the app_was_closed flag
    sessionStorage.removeItem('app_was_closed');
  });

  // Function to detect and prevent unauthorized profile access
  function setupProfileProtection() {
    // Store the current user ID
    let currentUserId = null;

    // Check for user ID changes every second
    setInterval(function() {
      // Get the current user ID from localStorage
      const storedUserId = localStorage.getItem('current_user_id');

      if (currentUserId === null && storedUserId) {
        // First time setting the user ID
        console.log(`Initial user ID set: ${storedUserId}`);
        currentUserId = storedUserId;
      } else if (storedUserId && currentUserId && storedUserId !== currentUserId) {
        // User ID has changed - this should never happen without a proper logout
        console.error(`SECURITY ALERT: User ID changed from ${currentUserId} to ${storedUserId} without proper logout!`);

        // Force logout immediately
        console.log('Forcing logout due to unauthorized user ID change');
        clearSessionOnExit();

        notifyFlutterSessionExpired();

        if (!sessionStorage.getItem(FLUTTER_BRIDGE_READY_KEY)) {
          console.warn('Fallback triggered: Reloading page to ensure session security.');
          location.reload();
        }
      }
    }, 1000); // Check every second
  }

  // Start profile protection on load
  setupProfileProtection();

  // Expose functions to Flutter
  window.flutterSessionHandler = {
    clearSession: clearSessionOnExit,
    setSupabaseClient: function(client) {
      window.supabaseClient = client;
    },
    forceLogout: function() {
      console.log('Force logout requested from Flutter');
      clearSessionOnExit();
      return true;
    }
  };

  console.log('Session handler initialized');
})();
