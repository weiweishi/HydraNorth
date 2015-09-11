FactoryGirl.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password 'password'
    after(:create) { |user| user.confirm! }

    factory :jill do
      email 'jilluser@example.com'
    end

    factory :dit do
      email 'dit.application.test@ualberta.ca'
    end

    factory :testshib do
      email 'myself@testshib.org'
    end

    factory :archivist, aliases: [:user_with_fixtures] do
      email 'archivist1@example.com'
    end

    factory :admin do 
      email 'admin@example.com'
      group_list 'admin'
    end

    factory :user_with_mail do
      after(:create) do |user|
        # TODO: what is this class for?
        # <span class="batchid ui-helper-hidden">fake_batch_noid</span>
        message = BatchMessage.new

        # Create examples of single file successes and failures
        (1..10).each do |number|
          file = MockFile.new(number.to_s, "Single File #{number.to_s}")
          User.batchuser().send_message(user, message.single_success("single-batch-success", file), message.success_subject, sanitize_text = false)
          User.batchuser().send_message(user, message.single_failure("single-batch-failure", file), message.failure_subject, sanitize_text = false)
        end

        # Create examples of mulitple file successes and failures
        files = []
        (1..50).each do |number|
          files << MockFile.new(number.to_s, "File #{number.to_s}")
        end
        User.batchuser().send_message(user, message.multiple_success("multiple-batch-success", files), message.success_subject, sanitize_text = false)
        User.batchuser().send_message(user, message.multiple_failure("multiple-batch-failure", files), message.failure_subject, sanitize_text = false)
      end
    end

    factory :curator do
      email 'curator1@example.com'
    end

    
    factory :new_user do
      email            'new_user@example.com'
      password         "123456789"
    end

    factory :legacy_user, :class => 'User' do
      email             'legacy_user@example.com'
      password          Digest::MD5.hexdigest("123456789")
      legacy_password   Digest::MD5.hexdigest("123456789")   
    end

  end
end

class MockFile
  attr_accessor :noid, :to_s, :id
  def initialize id, string
    self.noid = id
    self.id = id
    self.to_s = string
  end
end

class BatchMessage
  include Sufia::Messages
end
