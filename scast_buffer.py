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
    self.log_directory = expanduser("~/ppm")
    
  def add(self, char):
    self.buffer += char
    return self.process_buffer()
    
  def process_buffer(self):
    processed_reading = False
    self.log_buffer('before')
    while True:
      start = self.buffer.find(self.SCAST_TOKEN)
      if start == -1:
        self.log_error("SCAST token not found.")
        break

      self.buffer = self.buffer[start:]
      if len(self.buffer) < self.READING_COUNT_END:
        self.log_error("Buffer not long enough for reading count ({0} chars).".format(len(self.buffer)))
        break

      # If no comma found then the unit hasn't reported its readings so discard this SCAST.
      if self.buffer[self.COMMA_START:self.COMMA_END] != self.COMMA:
        self.buffer = self.buffer[self.READING_COUNT_END:]
        self.log_error("Comma token not found.")
        break

      reading_data_length = int(self.buffer[self.READING_COUNT_START:self.READING_COUNT_END].decode('hex'), 16)
      reading_count = (reading_data_length - 6) / 4

      scast_length = self.READING_DATA_START + (self.READING_DATA_LENGTH * reading_count)
      if len(self.buffer) < scast_length:
        self.log_error("Buffer not long enough for readings ({0} chars).".format(len(self.buffer)))
        break

      scast = Scast(self.buffer[:scast_length])
      self.buffer = self.buffer[scast_length:]
      self.log_buffer('after')
      processed_reading = True
    return processed_reading

  def log_buffer(self, when):
    log_time = datetime.now()
    with open("{}/{:%Y%m%d}.txt".format(self.log_directory, log_time), 'a+') as f:
      f.write("\n\nSCAST buffer at {:%d-%m-%Y %H:%M:%S}\n {} processing".format(log_time, when))
      f.write(' ' * 12)
      f.write(self.buffer)
      f.write("\n")
      if (when == 'after'):
        f.write('-' * 80)
        f.write('\n\n')      

  def log_error(self, message):
    log_time = datetime.now()
    with open("{}/{:%Y%m%d}.txt".format(self.log_directory, log_time), 'a+') as f:
      f.write("Buffer not processed: {0}".format(message))


