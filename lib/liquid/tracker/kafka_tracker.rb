require 'liquid/tracker/base'

require_relative '../scala-library-2.10.3.jar'
require_relative '../metrics-core-2.2.0.jar'
require_relative '../metrics-annotation-2.2.0.jar'
require_relative '../kafka_2.10-0.8.0.jar'

module Tracker
  class KafkaTracker < Base

    java_import 'kafka.javaapi.producer.Producer'
    java_import 'kafka.producer.ProducerConfig'
    java_import 'kafka.producer.KeyedMessage'

    def initialize(properties, dimensions = {})
      super(dimensions)
      @producer = Producer.new(ProducerConfig.new(properties))
    end

    def down?
      # TODO: async is fire and forget. we might want to handle
      # QueueFullExceptions later
      false
    end

    def event(obj, topic)
      @producer.send(KeyedMessage.new(topic, @serializer.dump(obj)))
    rescue => e
      # TODO: maybe fall back to FileTracker here
      $log.exception(e, "failed to log event=#{obj.inspect}")
    end

    def shutdown
      @producer.close if @producer
    end

  end
end
