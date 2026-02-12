
lambda { |stdout,stderr,status|
  output = stdout + stderr
  return :green if /^Passed!/.match(output)
  return :red   if /^Failed!/.match(output)
  return :amber
}
