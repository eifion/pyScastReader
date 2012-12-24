from scast import *

class ScastBuffer:

  SCAST_TOKEN = '53434153543a'
  CR_LF       = '0d0a'
  
  def __init__(self):
    self.buffer = ""
    
  def add(self, char):
    self.buffer += char
    self.process_buffer()
    
  def process_buffer(self):
    while True:
      start = self.buffer.find(SCAST_TOKEN)
      if start == -1:
        break

      self.buffer = self.buffer[start:]
      if len(self.buffer) < READING_COUNT_END:
        break

      reading_data_length = int(self.buffer[READING_COUNT_START:READING_COUNT_END].decode('hex'), 16)
      reading_count = (reading_data_length - 6) / 4

      scast_length = READING_DATA_START + (READING_DATA_LENGTH * reading_count)
      if len(self.buffer) < scast_length:
        break

      scast = self.buffer[:scast_length]
      self.buffer = self.buffer[scast_length:]

