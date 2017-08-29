# Collects IO stats from stdin and prints the stats to stderr.
# Original stdin is output to stdout.
#
# rubocop:disable all
class StreamCount
  BUFFER_SIZE   = 10240
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
    total_bytes = 0
    read_bytes = 0
    lines = 0
    output(bytes: total_bytes, lines: lines)
    while (read_bytes = @io.read_utf8(slice: @slice)) > 0
      total_bytes += read_bytes
      lines += count_new_lines(@slice)
      STDOUT.write(@slice[0, read_bytes])
      throttler { output(bytes: total_bytes, lines: lines) }
    end
    STDOUT.flush
    output(bytes: total_bytes, lines: lines)
  end

  def count_new_lines(slice)
    result = 0
    slice.each do |c|
      if c == 0x0A
        result += 1
      end
    end
    result
  end

  # output formatted stats to stderr.
  # Using throttle will limit how often we print to stderr to 5/second.
  def output(bytes, lines)
    msg = "\e[1G\e[2K%s seconds | %s kb [ %s kb/sec ] | %s lines [ %s lines/sec ]"
    seconds = (Time.utc_ticks - @start_time) / Time::Span::TicksPerSecond
    if seconds > 0
      STDERR.print(msg % [number_with_delimiter(seconds),
                          number_with_delimiter(bytes / 1024),
                          number_with_delimiter(bytes / seconds / 1024),
                          number_with_delimiter(lines),
                          number_with_delimiter(lines / seconds)])
    else
      STDERR.print(msg % [number_with_delimiter(seconds),
                          number_with_delimiter(bytes / 1024),
                          "?",
                          number_with_delimiter(lines),
                          "?"])
    end
  end

  def throttler
    if Time.utc_ticks > (@last_tick + TICK_DURATION)
      yield
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
