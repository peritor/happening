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
      logger.debug("Happening: #{msg}")
    end
    
    def self.info(msg)
      logger.debug("Happening: #{msg}")
    end
    
    def self.warn(msg)
      logger.debug("Happening: #{msg}")
    end
    
    def self.error(msg)
      logger.debug("Happening: #{msg}")
    end
    
  end
end