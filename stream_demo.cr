def run(io = STDIN)
  slice = Bytes.new(255)
  bytes_read = 0

  while (bytes_read = io.read_utf8(slice: slice)) > 0
    STDOUT.write(slice[0, bytes_read])
  end
  STDOUT.flush
end

run
