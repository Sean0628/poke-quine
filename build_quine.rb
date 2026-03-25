#!/usr/bin/env ruby
require 'base64'
require 'zlib'

Art = Struct.new(:id, :ascii, :non_space_count, :lead_pad, :suffix_slots, keyword_init: true)

PREFIX = 'eval$s=%w('.freeze
SUFFIX = ')*""'.freeze
DELIMITER = '<<<POKE>>>'.freeze
ART_DIR = File.expand_path('AA', __dir__)
OUTPUT_PATH = File.expand_path('quine.rb', __dir__)

def discover_art_ids
  ids = Dir.children(ART_DIR)
    .grep(/\A\d{4}\.txt\z/)
    .sort
    .map { |name| name.delete_suffix('.txt').to_i }

  return ids unless ids.empty?

  $stderr.puts "No art files found in #{ART_DIR}"
  exit 1
end

def find_lead_pad(ascii)
  lead_pad = 0
  ascii.lines.each do |line|
    blocks = line.rstrip.split(' ').map(&:length)
    return lead_pad if blocks.any? { |block| block > 6 }

    lead_pad += blocks.sum
  end
  lead_pad
end

def find_trail_pad(ascii)
  trail_pad = 0
  ascii.lines.reverse_each do |line|
    blocks = line.rstrip.split(' ').map(&:length)
    return trail_pad if blocks.any? { |block| block > 3 }

    trail_pad += blocks.sum
  end
  trail_pad
end

def suffix_slots(ascii)
  points = []
  ascii.lines.each_with_index do |line, row|
    line.chomp.chars.each_with_index do |char, col|
      points << [row, col] unless char == ' '
    end
  end

  slots = []
  0.upto(points.length - 4) do |index|
    p0, p1, p2, p3 = points[index, 4]
    next unless p0[0] == p1[0] && p1[0] == p2[0] && p2[0] == p3[0]
    next unless p1[1] == p0[1] + 1 && p2[1] == p1[1] + 1 && p3[1] == p2[1] + 1

    slots << index
  end
  slots
end

def load_art(id)
  padded_id = format('%04d', id)
  path = File.join(ART_DIR, "#{padded_id}.txt")
  unless File.exist?(path)
    $stderr.puts "Missing: #{path}"
    exit 1
  end

  ascii = File.read(path).rstrip
  non_space_count = ascii.chars.count { |char| char != ' ' && char != "\n" }
  $stderr.puts "Loaded ##{padded_id} (#{ascii.lines.count} lines, #{non_space_count} non-space)"

  Art.new(
    id: id,
    ascii: ascii,
    non_space_count: non_space_count,
    lead_pad: find_lead_pad(ascii),
    suffix_slots: suffix_slots(ascii)
  )
end

def encode_payload(payload)
  Base64.strict_encode64(Zlib::Deflate.deflate(payload, 9))
end

def build_logic(encoded:, lead_pads:, trail_pads:)
  lead_pad_code = "[#{lead_pads.join(',')}]"
  trail_pad_code = "[#{trail_pads.join(',')}]"

  'require"zlib";require"base64";' \
    "d=Zlib::Inflate.inflate(Base64.decode64(D)).split(#{DELIMITER.inspect});" \
    'm=d.length;x=(N%m)+1;aa=d[x-1];' \
    "lp=#{lead_pad_code}[x-1];tp=#{trail_pad_code}[x-1];" \
    'ci=$s.dup;ci.chop!while(ci.getbyte(-1)==59);j=ci.index(59.chr)||ci.length;ci="N="+x.to_s+ci[j..];' \
    'ns=aa.delete(32.chr+10.chr).length;' \
    'pf="eval$s=%w(";sf=")"+42.chr+34.chr*2;' \
    'ml=ns-lp-pf.length-ci.length-sf.length-tp;' \
    'c=pf+ci+";"*ml+sf;' \
    'l=lp;o="";i=0;aa.each_line{|r|cm=0;r.each_char{|h|if(h==10.chr);o<<10.chr;cm=0;elsif(h==32.chr);o<<32.chr;elsif(l>0);o<<(cm<1?35:(cm%2<1?48:51)).chr;cm+=1;l-=1;elsif(i<c.length);o<<c[i];i+=1;else;o<<(cm<1?35:(cm%2<1?48:51)).chr;cm+=1;end}};' \
    'print(o+10.chr)'
end

def build_inner_code(encoded:, lead_pads:, trail_pads:)
  "N=1;D=#{encoded.inspect};#{build_logic(encoded: encoded, lead_pads: lead_pads, trail_pads: trail_pads)}"
end

def resolve_trail_pads(arts, lead_pads, encoded)
  trail_pads = arts.map { |art| find_trail_pad(art.ascii) }

  4.times do
    inner_code = build_inner_code(encoded: encoded, lead_pads: lead_pads, trail_pads: trail_pads)
    required_slots = lead_pads.zip(arts.map(&:suffix_slots)).map do |lead_pad, slots|
      min_start = lead_pad + PREFIX.length + inner_code.length
      slot = slots.find { |index| index >= min_start }
      raise 'No suffix slot fits payload' unless slot

      slot
    end

    updated = arts.map.with_index do |art, index|
      art.non_space_count - required_slots[index] - SUFFIX.length
    end

    return trail_pads if updated == trail_pads

    trail_pads = updated
  end

  trail_pads
end

def verify_inner_code!(inner_code)
  if (position = inner_code =~ /\s/)
    $stderr.puts "ERROR: inner code has whitespace at pos #{position}!"
    exit 1
  end

  depth = 0
  inner_code.each_char do |char|
    depth += 1 if char == '('
    depth -= 1 if char == ')'
    if depth.negative?
      $stderr.puts 'ERROR: unbalanced parens!'
      exit 1
    end
  end

  return if depth.zero?

  $stderr.puts "ERROR: unbalanced parens (depth=#{depth})!"
  exit 1
end

def verify_capacity!(arts, lead_pads, trail_pads, inner_code)
  arts.each_with_index do |art, index|
    lead_pad = lead_pads[index]
    trail_pad = trail_pads[index]
    available = art.non_space_count - lead_pad - PREFIX.length - SUFFIX.length - trail_pad
    margin = available - inner_code.length
    $stderr.puts "  ##{art.id}: ns=#{art.non_space_count} lp=#{lead_pad} tp=#{trail_pad} avail=#{available} margin=#{margin}"
    next unless margin.negative?

    $stderr.puts "  ERROR: code too long for ##{art.id}!"
    exit 1
  end
end

def filler_char(comment_len)
  return '#' if comment_len.zero?

  comment_len.odd? ? '3' : '0'
end

def shape_quine(ascii:, non_space_count:, lead_pad:, trail_pad:, inner_code:)
  mid_pad = non_space_count - lead_pad - PREFIX.length - inner_code.length - SUFFIX.length - trail_pad
  core = PREFIX + inner_code + ';' * mid_pad + SUFFIX

  shaped = +''
  code_index = 0

  ascii.each_line do |line|
    comment_len = 0
    line.each_char do |char|
      if char == "\n"
        shaped << "\n"
        comment_len = 0
      elsif char == ' '
        shaped << ' '
      elsif code_index < lead_pad
        shaped << filler_char(comment_len)
        code_index += 1
        comment_len += 1
      elsif code_index < lead_pad + core.length
        shaped << core[code_index - lead_pad]
        code_index += 1
      else
        shaped << filler_char(comment_len)
        code_index += 1
        comment_len += 1
      end
    end
  end

  shaped << "\n" unless shaped.end_with?("\n")
  shaped
end

def roundtrip_status(shaped, lead_pad, inner_code, trail_pad)
  total = lead_pad + PREFIX.length + inner_code.length + SUFFIX.length + trail_pad
  written = shaped.chars.count { |char| char != ' ' && char != "\n" }
  written == total ? 'Roundtrip verification: PASS' : 'Roundtrip verification: FAIL'
end

art_ids = discover_art_ids
arts = art_ids.map { |id| load_art(id) }
lead_pads = arts.map(&:lead_pad)
encoded = encode_payload(arts.map(&:ascii).join(DELIMITER))

$stderr.puts "Pokemon count: #{arts.length}"
$stderr.puts "Base64: #{encoded.bytesize} bytes"

trail_pads = resolve_trail_pads(arts, lead_pads, encoded)
logic = build_logic(encoded: encoded, lead_pads: lead_pads, trail_pads: trail_pads)
inner_code = build_inner_code(encoded: encoded, lead_pads: lead_pads, trail_pads: trail_pads)

$stderr.puts "Logic length: #{logic.length}"
$stderr.puts "Inner code length: #{inner_code.length}"

verify_inner_code!(inner_code)
verify_capacity!(arts, lead_pads, trail_pads, inner_code)

shaped = shape_quine(
  ascii: arts.first.ascii,
  non_space_count: arts.first.non_space_count,
  lead_pad: lead_pads.first,
  trail_pad: trail_pads.first,
  inner_code: inner_code
)

File.write(OUTPUT_PATH, shaped)
$stderr.puts "Written #{File.basename(OUTPUT_PATH)} (#{File.size(OUTPUT_PATH)} bytes)"
$stderr.puts roundtrip_status(shaped, lead_pads.first, inner_code, trail_pads.first)
