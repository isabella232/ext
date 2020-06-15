if RUBY_PLATFORM == "java"
  java_import 'org.slf4j.LoggerFactory'
else
  require 'logger'
end

module Liquid
  class Logger

    def initialize(name)
      @java = RUBY_PLATFORM == "java"
      @logger = @java ? LoggerFactory.getLogger(name) : ::Logger.new(STDOUT)
      @exceptions = {}
      @exception_handlers = [method(:_log_error_exception)]
      reload!
    end

    def reload!
      if @java
        root = org.apache.log4j.Logger.getRootLogger
        appender = org.apache.log4j.ConsoleAppender.new
        appender.name = "default"
        appender.layout = org.apache.log4j.PatternLayout.new($conf.log.format)
        appender.threshold = org.apache.log4j.Level.toLevel($conf.log.level.to_s)
        appender.activateOptions
        root.removeAllAppenders
        root.addAppender(appender)
      else
        @logger = ::Logger.new(STDOUT)
        @logger.level = $conf.log.level
      end
    end

    def trace?
      @java ? @logger.trace_enabled? : @logger.trace?
    end

    def trace(*args, &block)
      return unless trace?
      args = yield if block_given?
      @logger.trace(format(*args))
    end

    def debug?
      @java ? @logger.debug_enabled? : @logger.debug?
    end

    def debug(*args, &block)
      return unless debug?
      args = yield if block_given?
      @logger.debug(format(*args))
    end

    def info?
      @java ? @logger.info_enabled? : @logger.info?
    end

    def info(*args, &block)
      return unless info?
      args = yield if block_given?
      @logger.info(format(*args))
    end

    def warn?
      @java ? @logger.warn_enabled? : @logger.warn?
    end

    def warn(*args, &block)
      return unless warn?
      args = yield if block_given?
      @logger.warn(format(*args))
    end

    def error?
      @java ? @logger.error_enabled? : @logger.error?
    end

    def error(*args, &block)
      return unless error?
      args = yield if block_given?
      @logger.error(format(*args))
    end

    def add_exception_handler(&block)
      @exception_handlers << block
    end

    def exception(exc, message = nil, attribs = {})
      @exception_handlers.each do |callback|
        callback.call(exc, message, attribs)
      end
    end

    def _log_error_exception(exc, message, attribs)
      ::Metrics.meter("exception:#{exc.class.to_s.tableize}").mark
      @exceptions[exc.class] ||= {}
      @exceptions[exc.class][exc.backtrace.first] ||= [System.nano_time, 1, 1]
      five_minutes_ago = System.nano_time - 300_000_000_000
      last, count, backoff = *@exceptions[exc.class][exc.backtrace.first]
      count = backoff = 1 if last < five_minutes_ago
      backoff = count > backoff ? backoff * 2 : backoff
      if count % backoff == 0
        error("exception", {
          class: exc.class,
          count: count,
          reason: exc.message,
          message: message,
          backtrace: exc.backtrace
        }.merge(attribs).merge(called_from))
      end
      @exceptions[exc.class][exc.backtrace.first] = [
        System.nano_time,
        count + 1,
        backoff
      ]
    end

    private

    def format(message, attribs = {})
      attribs.merge!(called_from) if $conf.log.caller
      attribs = attribs.map do |k,v|
        "#{k}=#{v.to_s.clean_quote}"
      end.join(' ')
      message += " #{attribs}" if attribs.length > 0
      message
    end

    # Return the first callee outside the liquid-ext gem
    def called_from
      location = caller.detect('unknown:0') do |line|
        line.match(/\/liquid(-|\/)ext/).nil?
      end
      file, line, _ = location.split(':')
      { :file => file, :line => line }
    end

  end
end
