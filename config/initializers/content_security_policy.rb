# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    # Keep CSP reasonably tight but compatible with existing markup.
    # Notes:
    # - We allow inline styles because views use `style="..."` attributes (e.g. clip-path).
    # - We allow the CDN used by importmap for `canvas-confetti`.
    policy.default_src :self
    policy.base_uri :self
    policy.object_src :none

    policy.img_src :self, :data
    policy.font_src :self, :data
    policy.style_src :self, :unsafe_inline
    policy.script_src :self, "https://cdn.jsdelivr.net"

    policy.connect_src :self
    policy.frame_ancestors :none
  end

  # Generate session nonces for permitted importmap and any other inline scripts Rails emits.
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
  config.content_security_policy_nonce_auto = true
end
