module Happening
  class Log
    
    @@logger = Logger.new(STDOUT)
    @@logger.level = Logger::ERROR
    
    def self.logger=(log)
      @@logger = log
    end
    
    def self.logger
      @@logger
    end
    
    def self.level=(lev)
      logger.level = lev
    end
    
    def self.level
      logger.level
    end
    
    def self.debug(msg)
      logger.debug(msg)
    end
    
    def self.info(msg)
      logger.info(msg)
    end
    
    def self.warn(msg)
      logger.warn(msg)
    end
    
    def self.error(msg)
      logger.error(msg)
    end
    
  end
end