# frozen_string_literal: true

require "pwned"
require "devise/pwned_password/hooks/pwned_password"

module Devise
  module Models
    # The PwnedPassword module adds a new validation for Devise Models.
    # No modifications to routes or controllers needed.
    # Simply add :pwned_password to the list of included modules in your
    # devise module, and all new registrations will be blocked if they use
    # a password in this dataset https://haveibeenpwned.com/Passwords.
    module PwnedPassword
      extend ActiveSupport::Concern

      included do
        validate :not_pwned_password, if: :password_required?
      end

      module ClassMethods
        Devise::Models.config(self, :min_password_matches)
        Devise::Models.config(self, :min_password_matches_warn)
        Devise::Models.config(self, :pwned_password_open_timeout)
        Devise::Models.config(self, :pwned_password_read_timeout)
        Devise::Models.config(self, :proxy)
      end

      def pwned?
        @pwned ||= false
      end

      def pwned_count
        @pwned_count ||= 0
      end

      # Returns true if password is present in the PwnedPasswords dataset
      # Implement retry behaviour described here https://haveibeenpwned.com/API/v2#RateLimiting
      def password_pwned?(password)
        @pwned = false
        @pwned_count = 0

        options = {
          "User-Agent" => "devise_pwned_password",
          read_timeout: self.class.pwned_password_read_timeout,
          open_timeout: self.class.pwned_password_open_timeout,
          proxy: self.class.proxy
        }
        pwned_password = Pwned::Password.new(password.to_s, options)
        begin
          @pwned_count = pwned_password.pwned_count
          @pwned = @pwned_count >= (persisted? ? self.class.min_password_matches_warn || self.class.min_password_matches : self.class.min_password_matches)
          return @pwned
        rescue Pwned::Error
          return false
        end

        false
      end

      private

        def not_pwned_password
          # This deliberately fails silently on 500's etc. Most apps wont want to tie the ability to sign up customers to the availability of a third party API
          if password_pwned?(password)
            errors.add(:password, :pwned_password)
          end
        end
    end
  end
end
