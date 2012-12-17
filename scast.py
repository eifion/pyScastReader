from datetime import *
from scast_reading import *
import psycopg2

class Scast:
  
  # Anatomy of an SCAST with readings: Note that the start and end 0D0A (CRLF) values will have been stripped from the data before it gets here.
  # 
  # Position: Data
  #  00 - 11: 53 43 41 53 54 3a                                       ASCII value for 'SCAST:'
  #  12 - 43: 30 30 30 44 36 46 30 30 30 30 33 35 30 41 37 31         ASCII values for the unit Id: 000D6F0000350A71
  #  44 - 45: 2c                                                      ASCII value for a comma
  #  46 - 49: 30 45                                                   ASCII values for Hex values for the length of the reading data: 30 45 = 0E = 14 bytes.
  #  50 - 51: 3d                                                      ASCII value for an equals sign.
  #  52 - 59: ff 00 00 1e                                             First byte: Unit Name (ff == 255 => MM) Last three bytes: Unit ID in hex: 00001e == 30
  #  60 - 63: 03 00                                                   Number of relays and relay state. 
  #  64 - 71: 01 b8 d4 41                                             The rest of the data is sets of four bytes containing the reading data. 
  #  72 - 79: 03 28 4a 42                                             The first byte of each set is the SensorId; the last three bytes are reading data.
  #                                                                   See ScastReading for how the readings are calculated
  
  COMMA_TOKEN                   = '2c'

  UNIT_ID_START_POS             = 12
  UNIT_ID_END_POS               = 44
  UNIT_NAME_START_POS           = 40
  UNIT_NAME_END_POS             = 42
  UNIT_AND_DATA_DELIMITER_START = 44
  UNIT_AND_DATA_DELIMITER_END   = 46
  READING_COUNT_START           = 46
  READING_COUNT_END             = 50
  UNIT_SERIAL_NUMBER_START      = 54
  UNIT_SERIAL_NUMBER_END        = 60
  RELAY_COUNT_START             = 60
  RELAY_COUNT_END               = 62
  RELAY_STATE_START             = 62
  RELAY_STATE_END               = 64
  READING_DATA_START            = 64
  READING_DATA_LENGTH           =  8  
  
  def __init__(self, hex_data):
    self.hex_data = hex_data
    self.readings = []
    self_received_at = datetime.now()
    print "Hex data: " + hex_data
    if self.process():
      self.save()
      
  def process(self):
    if (self.hex_data[self.UNIT_AND_DATA_DELIMITER_START:self.UNIT_AND_DATA_DELIMITER_END] != self.COMMA_TOKEN):
      return False
    
    # Unit
    self.unit_identifier = self.hex_data[self.UNIT_ID_START_POS:self.UNIT_ID_END_POS]
    self.unit_name = self.get_unit_name()
    
    # Relays
    self.relay_count = int(self.hex_data[self.RELAY_COUNT_START:self.RELAY_COUNT_END], 16)
    if self.relay_count > 3:
      self.relay_count = 3
    
    self.relay_state = int(self.hex_data[self.RELAY_STATE_START:self.RELAY_STATE_END], 16)
    
    # Readings
    reading_data_length = int(self.hex_data[self.READING_COUNT_START:self.READING_COUNT_END].decode('hex'), 16)
    reading_count = (reading_data_length - 6) / 4
    
    for i in range(reading_count):
      reading_start = self.READING_DATA_START + (i * self.READING_DATA_LENGTH)
      reading_data = self.hex_data[reading_start:(reading_start + self.READING_DATA_LENGTH)]
      self.readings.append(ScastReading(reading_data))
    
    return True
    
  def get_unit_name(self):
    unit_code = self.hex_data[self.UNIT_NAME_START_POS:self.UNIT_NAME_END_POS]
    if (unit_code == "00"):
      unit_code_name = "ZWU"
    else:
      unit_code_name = "MM"

    unit_serial_number = str(int(self.hex_data[self.UNIT_SERIAL_NUMBER_START:self.UNIT_SERIAL_NUMBER_END], 16)).rjust(8, '0')
    return unit_code_name + unit_serial_number
  
      
  def save(self):
    conn = psycopg2.connect("dbname=pyppm user=pyppm password=PyPPM")
    cur = conn.cursor()
    identifier = ''.join([chr(ord(c)) for c in self.unit_identifier.decode('hex')])
    print "Unit name: {0}. Unit identifier: {1}".format(self.unit_name, identifier)
    for reading in self.readings:
      cur.execute("SELECT \"AddReading\"(%s, %s, %s, %s);", (self.unit_name, identifier, reading.sensor_id, reading.reading_value))
      print "Sensor id:{0}. Reading value: {1}".format(reading.sensor_id, reading.reading_value)
    conn.commit()
    cur.close()
    conn.close()



