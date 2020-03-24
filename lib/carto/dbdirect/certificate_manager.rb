require 'openssl'
require 'aws-sdk-acmpca'
require 'base64'
require 'json'

def with_env(vars)
  old = {}
  vars.each do |key, value|
    key = key.to_s
    old[key] = ENV[key]
    ENV[key] = value
  end
  yield
ensure
  vars.each do |key, value|
    key = key.to_s
    ENV[key] = old[key]
  end
end

module Carto
  module Dbdirect

    SEP = '-----END CERTIFICATE-----'.freeze

    # TODO: this uses aws cli at the moment.
    # if having it installed in the hosts is not convenient we could
    # switch to use some aws-sdk-* gem

    # Private CA certificate manager for dbdirect
    # requirements: openssl, aws cli v2 installed in the system
    module CertificateManager
      module_function

      def generate_certificate(config:, username:, passphrase:, ips:, validity_days:, server_ca:)
        certificates = nil
        arn = nil
        key = openssl_generate_key(passphrase)
        csr = openssl_generate_csr(username, key, passphrase)
        with_aws_credentials(config) do
          arn = aws_issue_certificate(config, csr, validity_days)
          puts ">ARN #{arn}" if $DEBUG
          certificate = aws_get_certificate(config, arn)
          certificates = {
            client_key: key,
            client_crt: certificate
          }
          certificates[:server_ca] = aws_get_ca_certificate_chain(config) if server_ca
        end
        [certificates, arn]
      end

      def revoke_certificate(config:, arn:, reason: 'UNSPECIFIED')
        with_aws_credentials(config) do
          aws_revoke_certificate(config, arn, reason)
        end
      end

      private

      class <<self
        private

        def openssl_generate_key(passphrase)
          key = OpenSSL::PKey::RSA.new 2048
          if passphrase.present?
            cipher = OpenSSL::Cipher.new 'AES-128-CBC'
            key = key.export cipher, passphrase
          end
          key
        end

        def openssl_generate_csr(username, key, passphrase)
          subj = OpenSSL::X509::Name.parse("/C=US/ST=New York/L=New York/O=CARTO/OU=Customer/CN=#{username}")
          if passphrase.present?
            key = OpenSSL::PKey::RSA.new key, passphrase
          else
            key = OpenSSL::PKey::RSA.new key
          end
          csr = OpenSSL::X509::Request.new
          csr.version = 0
          csr.subject = subj
          csr.public_key = key.public_key
          csr.sign key, OpenSSL::Digest::SHA256.new
          csr.to_pem
        end

        def aws_acmpca_client
          @aws_acmpca_client ||= Aws::ACMPCA::Client.new
        end

        def aws_issue_certificate(config, csr, validity_days)
          resp = aws_acmpca_client.issue_certificate(
            certificate_authority_arn: config['ca_arn'],
            csr: csr,
            signing_algorithm: "SHA256WITHRSA",
            template_arn: "arn:aws:acm-pca:::template/EndEntityClientAuthCertificate/V1",
            validity: {
              value: validity_days,
              type: "DAYS"
            }
          )
          resp.certificate_arn
        end

        def aws_get_certificate(config, arn)
          resp = aws_acmpca_client.get_certificate({
            certificate_authority_arn: config['ca_arn'],
            certificate_arn: arn
          })
          run cmd
          resp.certificate
        end

        def aws_get_ca_certificate_chain(config)
          # TODO: we could cache this
          resp = aws_acmpca_client.get_certificate_authority_certificate({
            certificate_authority_arn: "Arn", # required
          })
          resp.certificate_chain
        end

        def aws_revoke_certificate(config, arn, reason)
          serial = serial_from_arn(arn)
          resp = aws_acmpca_client.revoke_certificate({
            certificate_authority_arn: config['ca_arn'],
            certificate_serial: serial,
            revocation_reason: reason
          })
        end

        def serial_from_arn(arn)
          match = /\/certificate\/(.{32})\Z/.match(arn)
          raise "Invalid arn format #{arn}" unless match
          match[1].scan(/../).join(':')
        end

        def with_aws_credentials(config, &blk)
          with_env(
            AWS_ACCESS_KEY_ID:     config['aws_access_key_id'],
            AWS_SECRET_ACCESS_KEY: config['aws_secret_key'],
            AWS_DEFAULT_REGION:    config['aws_region'],
            &blk
          )
        end
      end
    end
  end
end
