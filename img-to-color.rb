#!/usr/bin/env ruby

# encoding: utf-8

require "rubygems"
require "RMagick"
require "matrix"

include Magick
include Math

if ARGV.size < 1
  $stderr.puts "Usage: ./img-to-color.rb IMAGE_FILE"
  $stderr.puts 
  exit -1
end

image = ImageList.new(ARGV[0]).first

$stderr.puts "Image: '#{image.filename}'"

class Vector

  def sqdist(rhs)
    dx = self - rhs
    # wraparound for hue (dx[0])
    #if dx[0].abs > 180
    #    dx[0] = 360 - dx[0].abs
    #end
    dx.inner_product dx
  end

  def []=(i, rhs)
    @elements[i] = rhs
  end

  def to_rgbhex
    scale = 256.0
    c = Pixel.from_hsla *self
    scale = 256
    sprintf "#%02x%02x%02x", c.red / scale, c.green / scale, c.blue / scale
  end

  def hash
      hue_binsize = 10
      sat_binsize = 20
      lig_binsize = 20
      [ (self[0] / hue_binsize).to_i, (self[1] / sat_binsize).to_i,
          (self[2] / lig_binsize).to_i ]
  end

  def self.unhash(arr)
      hue_binsize = 10
      sat_binsize = 20
      lig_binsize = 20
      Vector[arr[0] * hue_binsize, arr[1] * sat_binsize, arr[2] * lig_binsize]
  end

end

def GaussianKernel(h = 1.0)
  @h = h * h
  def k(x0, x)
    Math.exp -(x0.sqdist x) / @h
  end
  method(:k)
end

def m(x, data, k)
  hue_min = x[0] - 180.0
  hue_max = x[0] + 180.0
  num = Vector[0.0, 0.0, 0.0]
  denom = 0.0
  data.each do |xi|
    # wrap around at 360 degrees
    xi = Vector.elements xi
    if xi[0] < hue_min
        xi[0] += 360
    elsif xi[0] > hue_max
        xi[0] -= 360
    end
    kval = k(xi, x)
    num += xi * kval
    denom += kval
  end
  new_x = num / denom
  new_x[0] = new_x[0] % 360.0
  new_x
end

data = Array.new
image.each_pixel do |pixel, column, row|
    hsl = pixel.to_hsla[0..2]
    # somethings wrong with to_hsla
    #hsl[1] *= 100.0 / 255.0
    #hsl[2] *= 100.0 / 255.0
    data.push Vector.elements hsl
end

def meanshift(data)
    # initialize stuff
    kernel_width = 10.0
    k = GaussianKernel kernel_width
    x = data.sample
    puts x
    
    eps = 0.1
    iters = 20
    (1..iters).each do |i|
      x_new = m(x, data, k)
      if (x_new.sqdist x).abs < eps
        break
      end
      x = x_new
      puts x
    end
    
    x.to_rgbhex
end

def histogram(data)
    hist = {}
    hist.default = 0
    data.each do |hsl|
        hist[hsl.hash] += 1 
    end
    m = hist.each_pair.max { |a,b| a[1] <=> b[1] }
    (Vector.unhash m[0]).to_rgbhex
end

hex = histogram(data)
open("#{image.filename}.html", 'w') { |f|
    f.puts "<html><body bgcolor='#{hex}'>"
    f.puts "<img src='#{image.filename}' />"
    f.puts "</body></html>"
}
