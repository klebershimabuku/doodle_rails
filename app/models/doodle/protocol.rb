module Doodle
  class Protocol < ActiveRecord::Base
    include AASM
    belongs_to :channel
    belongs_to :user

    aasm column: :status do
      state :waiting, initial: true
      state :in_progress
      state :finalized

      after_all_transitions :log_status_change

      event :progress do
        before do
          self.update(in_progress_at: Time.now)
        end

        transitions from: :waiting, to: :in_progress
      end

      event :finalize do
        before do
          self.update(finalized_at: Time.now)
        end

        transitions from: :in_progress, to: :finalized
      end
    end

    scope :waiting_in_channel, -> (channel){ joins(:channel).where(status: :waiting, 'doodle_channels.name' => channel) }

    def duration
      (self.finalized_at - self.created_at).round
    end

    def log_status_change
      Rails.logger.info "[DOODLE] [PROTOCOL] - Protocol #{self.id} of customer #{self.customer_login} changed from #{aasm.from_state} to #{aasm.to_state}"
    end

    def add_analyst_into(user)
      self.user = user
      self.save
    end

    def add_participant_into_conversation(login)
      conversation = Layer::Conversation.find(self.conversation_id)
      conversation.participants << login
      conversation.save
    end

    def remove_participant_from_conversation(login)
      conversation = Layer::Conversation.find(self.conversation_id)
      conversation.participants = conversation.participants - [login]
      conversation.save
    end

    def self.next(channel = 'corporativo')
      protocol = self.waiting_in_channel(channel).first
      protocol.progress!
      protocol
    end

  end
end
