;(function($, window, document, undefined) {
  'use strict';

  var defaults = {};

  function EffectiveUjs(element, command, options) {
    if(typeof(command) === 'string') { // Convert to camelCase
      command = command.replace(/-([a-z])/g, function (str) { return str[1].toUpperCase(); });
    }

    if(typeof(this[command]) === 'function') {
      this[command]($(element), $.extend({}, defaults, options));
    }
  }

  $.extend(EffectiveUjs.prototype, {

    // Converts all inputs to required fields
    // $('#div-with-inputs').effective('inputs-required')
    // $('input').effective('inputs-required')
    inputsRequired: function(element, options) {
      var elements = (element.first().is(':input') ? element : element.find('input,select,textarea'));

      elements.each(function(index) {
        var input = $(this);
        var formGroup = input.closest('.form-group');

        if(input.attr('type') == 'hidden') { return; }
        if(input.hasClass('optional') && (input.attr('name') || '').indexOf('[address2]') > -1) { return; } // EffectiveAddresses

        // Require the input
        input.prop('required', true);

        // Add the *
        formGroup.find('abbr').remove();
        input.parent().find('abbr').remove();

        if(input.parent().is('label') && input.parent().parent().hasClass('radio') == false) {
          input.after("<abbr title='required'>*</abbr> ");
        } else if(formGroup.length > 0) {
          formGroup.find('label').first().prepend("<abbr title='required'>*</abbr> ");
        } else {
          input.parent().find('label').prepend("<abbr title='required'>*</abbr> ");
        }

        if(formGroup.length > 0) {
          formGroup.removeClass('optional').addClass('required');
          formGroup.find('.optional').removeClass('optional').addClass('required');
        }
      });
    },

    // Converts all inputs to non-required fields
    // $('#div-with-inputs').effective('inputs-optional')
    // $('input').effective('inputs-optional')
    inputsOptional: function(element, options) {
      var elements = (element.first().is(':input') ? element : element.find('input,select,textarea'));

      elements.each(function(index) {
        var input = $(this);
        var formGroup = input.closest('.form-group');

        if(input.attr('type') == 'hidden') { return; }

        // Un-require the input
        input.prop('required', false).removeAttr('required');

        // Remove the *
        formGroup.find('abbr').remove();
        input.parent().find('abbr').remove();

        if(formGroup.length > 0) {
          formGroup.removeClass('required').addClass('optional');
          formGroup.find('.required').removeClass('required').addClass('optional');
        }
      });
    }

  });

  $.fn.effective = function(command, options) {
    return this.each(function() { new EffectiveUjs(this, command, options); });
  };

})(jQuery, window, document);
