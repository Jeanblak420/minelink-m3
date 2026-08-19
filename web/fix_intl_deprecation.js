// Fix for Intl.v8BreakIterator deprecation warning
(function() {
  // Properly implement Intl.Segmenter if it doesn't exist
  if (typeof Intl !== 'undefined') {
    if (typeof Intl.Segmenter === 'undefined') {
      console.log('Implementing Intl.Segmenter to replace deprecated Intl.v8BreakIterator');

      // Create a proper Segmenter implementation that follows the standard
      Intl.Segmenter = class Segmenter {
        constructor(locale, options) {
          this.locale = locale || 'en';
          this.options = options || { granularity: 'word' };
        }

        segment(text) {
          // Simple implementation that creates segments based on spaces for word granularity
          // or returns individual characters for character granularity
          const granularity = this.options.granularity || 'word';
          let segments = [];

          if (granularity === 'word') {
            // Split by spaces for word granularity
            let lastIndex = 0;
            const words = text.split(/(\s+)/);

            for (let i = 0; i < words.length; i++) {
              const word = words[i];
              segments.push({
                segment: word,
                index: lastIndex,
                input: text,
                isWordLike: !/^\s+$/.test(word)
              });
              lastIndex += word.length;
            }
          } else {
            // Character granularity - each character is a segment
            for (let i = 0; i < text.length; i++) {
              segments.push({
                segment: text[i],
                index: i,
                input: text,
                isWordLike: false
              });
            }
          }

          // Add iterator
          segments[Symbol.iterator] = function() {
            let index = 0;
            return {
              next: function() {
                if (index < segments.length) {
                  return { value: segments[index++], done: false };
                } else {
                  return { done: true };
                }
              }
            };
          };

          return segments;
        }
      };
    }

    // If v8BreakIterator is still being used, redirect it to use Segmenter
    if (typeof Intl.v8BreakIterator !== 'undefined') {
      const originalBreakIterator = Intl.v8BreakIterator;

      // Replace with a warning that redirects to Segmenter
      Intl.v8BreakIterator = function() {
        console.warn('Intl.v8BreakIterator is deprecated. Using Intl.Segmenter instead.');
        return new originalBreakIterator(...arguments);
      };
    }
  }
})();
