# Collects IO stats from stdin and prints the stats to stderr.
# Original stdin is output to stdout.
#
# rubocop:disable all
class StreamCount

  BUFFER_SIZE   = 1024
  TICK_DURATION = 20000 # microsecond

  @start_time : Int64
  @last_tick : Int64

  def initialize(@io = STDIN)
    @start_time = Time.utc_ticks
    @last_tick = Time.utc_ticks
    @slice = Bytes.new(BUFFER_SIZE)
  end

  # Do the work
  def run
    bytes = 0
    lines = 0
    output(bytes: bytes, lines: lines, throttle: false)
    while (@io.read(slice: @slice) > 0)
      STDOUT.print(@slice)
      bytes += @slice.size
      @slice.each do |c|
        if c == 0x0A 
          lines += 1
        end
      end
      # lines += new_lines.size # @slice.count("\n")
      output(bytes: bytes, lines: lines, throttle: true)
    end
    output(bytes: bytes, lines: lines, throttle: false)
  end

  # output formatted stats to stderr.
  # Using throttle will limit how often we print to stderr to 5/second.
  def output(bytes, lines, throttle=true)
    throttler(force: !throttle) do
      msg = "\e[1G\e[2K%s seconds | %s kb [ %s kb/sec ] | %s lines [ %s lines/sec ]"
      duration = Time.utc_ticks - @start_time
      if duration > 0
        STDERR.print(msg % [number_with_delimiter(duration),
                            number_with_delimiter((bytes / 1024)),
                            number_with_delimiter((bytes / duration / 1024).to_i),
                            number_with_delimiter(lines),
                            number_with_delimiter((lines / duration).to_i)])
      end
    end
  end

  def throttler(force = true, &block)
    if force || Time.utc_ticks > (@last_tick + TICK_DURATION)
      block.call
      @last_tick = Time.utc_ticks
    end
  end

  # Thanks ActiveSupport::NumberHelper
  def number_with_delimiter(number, delimiter = ',')
    number.to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{delimiter}")
  end
end

counter = StreamCount.new(io: STDIN)
counter.run
