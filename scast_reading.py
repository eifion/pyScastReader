# An SCAST reading is four bytes long. The first byte is the sensor type in hex.
# The other three represent the reading with the least-significant byte first.
class ScastReading:
  def __init__(self, reading):
    if len(reading) != 8:
      return
      
    self.process_reading(reading)
    
  def process_reading(self, reading):
    self.sensor_id = int(reading[0:2], 16)
    reading_hex = self.reverse_bytes(reading[2:])
    self.reading_value = self.get_spi_value(reading_hex)
    self.is_error_reading = (self.reading_value == '800000')
      
  def reverse_bytes(self, reading):
    return reading[4:6] + reading[2:4] + reading[0:2]
    
  def get_spi_value(self, reading):
    if (reading == '000000' or reading == 'FFFFFF' or reading == '8000000'):
      return 0
    
    reading = reading.ljust(8, '0')
    byte1 = int(reading[0:2], 16)
    byte2 = int(reading[2:4], 16)
    byte2_nibble1 = byte2 >> 4
    
    # Fractional part
    frac = int(reading[3:], 16)
    frac += (2 ** 20) * (byte2_nibble1 | 8)
    if byte1 > 127: 
      frac *= -1
    
    # Exponential part
    exp = (byte1 & 127) * 2
    if (byte2 & 128 == 128): 
      exp += 1
    
    exp -= 127
    
    return frac * (2 ** (exp - 23))
