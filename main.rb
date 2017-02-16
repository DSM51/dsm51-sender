require 'serialport'
require 'ihex'
require 'timeout'

$port = SerialPort.new '/dev/ttyUSB0', 57600, 8, 1, SerialPort::NONE


class DSM
  attr_reader :port

  def initialize(port)
    @port = port
  end

  def send(*bytes)
    payload = bytes + [crc(bytes)]
    # puts "send: #{payload.map { |x| x.to_s(16) }}"
    port.write payload.map(&:chr).join
  end

  def recv(size)
    size.times.map { port.read(1).ord }
  end

  def crc(bytes)
    256 - bytes.inject(0) { |s,i| (s+i)%256 }
  end


  def ping
    send 0x54
    Timeout::timeout(0.5) do
    	recv(1).first == 0x43
    end
  rescue Timeout::Error
  	false
  end

  def upload
    send 0x51
    sleep 0.15
    recv(1).first == 0x06
  end

  def code(iteration)
    send 0x50, 0x00, 0x00, iteration
    sleep 0.15
    recv(1).first == 0x06
  end

  def restart
    send 0x52
    recv(1).first == 0x06
  end
end



class IHex::Binary
	def flat
		address_space.map { |address| self[address] || 0xff }
	end
end


dsm = DSM.new($port)
parser = IHex::Parser.new
bin = parser.parse(File.read('/home/user/Desktop/rzeszot.hex'))



if !dsm.ping
	puts "!!! ping"
	exit 1
end


puts dsm.upload

bin.flat.each_slice(256).each_with_index do |chunk, index|
	chunk.fill(0xff, chunk.length...256)

	puts " * send part: #{index}"
	
	puts "   => header #{dsm.code index}"
	dsm.send *chunk
	
	puts "   => data #{dsm.recv(1).first == 0x06}"
	puts
end

puts dsm.restart


