#!/usr/bin/env ruby
# SPDX-License-Identifier: MIT
require 'json'
require 'openssl'
require 'open3'
require 'stringio'
require 'tmpdir'
require 'fileutils'

ID = 'hehggadaopoacecdllhhajmbjkdcmajg'.freeze

def varint(io)
  value = 0
  10.times do |index|
    byte = io.getbyte or abort 'Truncated CRX header'
    value |= (byte & 127) << (7 * index)
    return value if byte < 128
  end
  abort 'Invalid CRX header'
end

def fields(bytes)
  io = StringIO.new(bytes)
  result = []
  until io.eof?
    tag = varint(io)
    abort 'Unsupported CRX field' unless tag % 8 == 2
    length = varint(io)
    abort 'Truncated CRX field' if length > bytes.bytesize - io.pos
    result << [tag / 8, io.read(length)]
  end
  result
end

chrome = '/Applications/Google Chrome.app/Contents/Info.plist'
version, status = Open3.capture2('/usr/bin/defaults', 'read', chrome, 'CFBundleShortVersionString')
version = version.strip
abort 'Install Google Chrome in /Applications first.' unless status.success? && version.match?(/\A\d+(\.\d+){3}\z/)

url = "https://clients2.google.com/service/update2/crx?response=redirect&prodversion=#{version}&acceptformat=crx3&x=id%3D#{ID}%26uc"
crx, status = Open3.capture2('/usr/bin/curl', '-fsSL', '--proto', '=https', '--proto-redir', '=https', '--max-time', '60', '--max-filesize', '20000000', url, binmode: true)
abort 'Google did not return a CRX3 package.' unless status.success? && crx.start_with?("Cr24\x03\0\0\0")
size = crx[8, 4]&.unpack1('V')
abort 'Invalid CRX header length' unless size && size.between?(1, crx.bytesize - 13)
header = fields(crx[12, size])
signed = header.to_h.fetch(10000)
archive = crx[(12 + size)..-1]
proof = header.select { |tag, _| [2, 3].include?(tag) }.map { |_, value| fields(value).to_h }.find do |entry|
  hash = OpenSSL::Digest::SHA256.hexdigest(entry.fetch(1))[0, 32]
  hash.tr('0123456789abcdef', 'abcdefghijklmnop') == ID
end
abort 'Official extension ID did not match.' unless proof
key = proof.fetch(1)
payload = "CRX3 SignedData\0" + [signed.bytesize].pack('V') + signed + archive
abort 'CRX signature verification failed.' unless OpenSSL::PKey.read(key).verify('SHA256', proof.fetch(2), payload)
abort 'Signed CRX ID did not match.' unless fields(signed).to_h[1] == [ID.tr('abcdefghijklmnop', '0123456789abcdef')].pack('H*')

root = ARGV.fetch(0, File.join(Dir.home, 'Library/Application Support/Chrome ChatGPT Setup'))
FileUtils.mkdir_p(root, mode: 0700)
Dir.mktmpdir('.prepare-', root) do |temp|
  zip = File.join(temp, 'package.zip')
  File.binwrite(zip, archive)
  manifest, status = Open3.capture2('/usr/bin/unzip', '-p', zip, 'manifest.json')
  abort 'Cannot read extension manifest.' unless status.success?
  manifest = JSON.parse(manifest)
  release = manifest.fetch('version')
  abort 'Invalid extension version' unless release.match?(/\A\d+(\.\d+){0,3}\z/)
  dest = File.expand_path(release, root)
  abort "Version directory already exists: #{dest}" if File.exist?(dest) || File.symlink?(dest)
  extracted = File.join(temp, 'extension')
  abort 'Cannot extract extension' unless system('/usr/bin/unzip', '-q', zip, '-x', '_metadata/*', '-d', extracted)
  manifest['key'] = [key].pack('m0')
  File.write(File.join(extracted, 'manifest.json'), JSON.pretty_generate(manifest) + "\n")
  File.rename(extracted, dest)
  puts "Verified extension #{release}: #{dest}"
  puts 'Open chrome://extensions and choose Developer mode → Load unpacked.'
end
