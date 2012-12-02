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
    s = self.buffer.find(self.SCAST_TOKEN)
    if s == -1:
      return
    
    e = self.buffer.find(self.CR_LF, s)
    if e == -1:
      return
    
    scast = Scast(self.buffer[s:e])
    self.buffer = self.buffer[e+4:]
      
    
  
