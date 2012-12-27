from scast import *

class ScastBuffer:

  SCAST_TOKEN = '53434153543a'
  CR_LF       = '0d0a'
  COMMA       = '2c'

  COMMA_START                   = 44
  COMMA_END                     = 46
  READING_COUNT_START           = 46
  READING_COUNT_END             = 50
  READING_DATA_START            = 64
  READING_DATA_LENGTH           =  8 
  
  def __init__(self):
    self.buffer = ""
    
  def add(self, char):
    self.buffer += char
    return self.process_buffer()
    
  def process_buffer(self):
    processed_reading = False
    while True:
      start = self.buffer.find(self.SCAST_TOKEN)
      if start == -1:
        break

      self.buffer = self.buffer[start:]
      if len(self.buffer) < self.READING_COUNT_END:
        break

      # If no comma found then the unit hasn't reported its readings so discard this SCAST.
      if self.buffer[self.COMMA_START:self.COMMA_END] != COMMA:
        self.buffer = self.buffer[self.READING_COUNT_END]
        break

      reading_data_length = int(self.buffer[self.READING_COUNT_START:self.READING_COUNT_END].decode('hex'), 16)
      reading_count = (reading_data_length - 6) / 4

      scast_length = self.READING_DATA_START + (self.READING_DATA_LENGTH * reading_count)
      if len(self.buffer) < scast_length:
        break

      scast = Scast(self.buffer[:scast_length])
      self.buffer = self.buffer[scast_length:]
      processed_reading = True
    return processed_reading

