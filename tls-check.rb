#!/usr/bin/env ruby

# https://superuser.com/questions/109213/how-do-i-list-the-ssl-tls-cipher-suites-a-particular-website-offers
# https://www.feistyduck.com/library/openssl-cookbook/online/ch-testing-with-openssl.html

require "exec-simple"
require "open3"
require "timeout"

$debug = 0
# $debug = 1

server = ARGV[0]
port = ARGV[1]
timeout = ARGV[2]

$timeout = 3

$send_sni = 1
$show_certs = 1
$check_ocsp = 1

if server == nil or server.size == 0
  puts "Missing server name/ip/domain"
  exit 1
end

if port == nil or port.size == 0
  puts "Missing port"
  exit 1
end

if timeout == nil or timeout.to_i < 1
  $timeout = 3
else
  $timeout = timeout.to_i
end

$delay = 1

def getOpensslCiphers()
  res = {}
  cihpers_filter = "ALL:eNULL"
  cmd = "openssl ciphers '#{cihpers_filter}'" # All avaliable by OpenSSL and OS

  cihpers_filter = "ECDHE+AES:@STRENGTH:+AES256" # Strong
  cmd = "openssl ciphers '#{cihpers_filter}'" # Customised HIGH

  cmd = "openssl ciphers" # OpenSSL and OS Defaults

  cihpers_filter = "HIGH:MEDIUM:!RC4:!aNULL:!eNULL:!LOW:!3DES:!MD5:!EXP:!PSK:!SRP:!DSS"
  cmd = "openssl ciphers '#{cihpers_filter}'" # Customised HIGH

  stdout, stderr, status = ExecSimple.run(cmd)
  res["stdout"] = stdout
  res["stderr"] = stderr
  res["status"] = status
  return res
end

def checkCipher(cipher, server, port, timeout)
  res = {}
  opts = []
  opts << "-servername #{server}" if $send_sni > 0
  opts << "-showcerts" if $show_certs > 0
  opts << "-status" if $check_ocsp > 0
  cmd = "echo -n | openssl s_client -cipher \"#{cipher}\" -connect #{server}:#{port} #{opts.join(" ")}"

  stdout, stderr, status = ExecSimple.run(cmd, timeout: timeout)
  res["stdout"] = stdout
  res["stderr"] = stderr
  res["status"] = status
  return res
end

ciphers = getOpensslCiphers["stdout"].split(":")

ciphersBlacklist = []
File.open("blacklist").readlines.each do |l|
  l = l.strip.chomp
  ciphersBlacklist << l if l.size != 0
end

STDERR.puts("### Number of Ciphers to be tested: #{ciphers.size}")
STDERR.puts("### Timeout per test: #{$timeout}")
STDERR.puts("### Delay between tests: #{$delay}")

ciphers.each do |c|
  cipherRegex = /Cipher is[\s\t]+([A-Z0-9\_\-]+)/
  renegotiationSupportRegex = /(Secure Renegotiation IS supported|Secure Renegotiation IS NOT supported)/i
  res = "0"
  renegotiationSupport = "NO,"
  print "Testing #{c.chomp}...  "
  if ciphersBlacklist.include?(c)
    puts "BLACKLISTED Chiper"
    next
  end

  res = checkCipher(c, server, port, $timeout)
  if res["status"] == nil
    puts "NO, Timeout"
    next
  else
    if res["stderr"] =~ /(\:error\:|handshake failure\:)/
      if $debug > 0
        puts "NO, #{res["stderr"]}"
      else
        puts "NO, #{res["stderr"].split(":")[5]}"
      end
    else
      if res["stdout"] =~ renegotiationSupportRegex
        renegotiationSupport = $1
      end
      case res["stdout"]
      when cipherRegex
        chiperUsed = $1
        if c.chomp == chiperUsed
          puts "CONNECTED: #{chiperUsed}, YES, #{renegotiationSupport}"
        else
          puts "CONNECTED ~: #{chiperUsed}, NO, #{renegotiationSupport}"
        end
      when /Cipher is[\s\t]+\:[\s\t]+([A-Z0-9\_\-]+)/
        chiperUsed = $1
        if c.chomp == chiperUsed
          puts "CONNECTED: #{chiperUsed}, YES, #{renegotiationSupport}"
        else
          puts "CONNECTED ~: #{chiperUsed}, NO, #{renegotiationSupport}"
        end
      else
        puts "UNKNOWN RESPONSE"
        STDERR.puts("ERR_DEBUG: #{res}}")
      end
    end
  end
  STDERR.puts("DEBUG_1: #{res}") if $debug > 1
  sleep($delay)
end
