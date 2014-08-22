module RawFile

using IniFile

import Base: size, ndims, read, get, setindex!, getindex

export Rawfile, read_raw, write_raw

type Rawfile
  filename::String
  extRaw::String
  extHeader::String
  dtype
  size

  function Rawfile(filename::String; extRaw=".dat", extHeader=".srm")
    s = split(filename,".")
    if length(s) == 1
      fileWithoutExt = filename
    else
      pop!(s)
      fileWithoutExt = *(s...)
    end
    f = new(fileWithoutExt, extRaw, extHeader)
    if filesize(f.filename*f.extHeader) > 0
      read_srm(f)
    end
    f
  end

  function Rawfile(filename::String, dtype, size; extRaw=".dat", extHeader=".srm")
    f = Rawfile(filename, extRaw = extRaw, extHeader = extHeader)
    f.size = size
    f.dtype = dtype
    f
  end
end

function read_raw(filename::String; extRaw=".dat", extHeader=".srm")
  f = Rawfile(filename, extRaw = extRaw, extHeader = extHeader)
  read_srm(f)
  f[]
end

function write_raw(filename::String, x; extRaw=".dat", extHeader=".srm")
  f = Rawfile(filename, extRaw = extRaw, extHeader = extHeader)
  f[] = x
end

function read_srm(f::Rawfile)
  ini = Inifile()
  read(ini, f.filename*f.extHeader)
  f.size = int(split(get(ini,"size"),","))
  f.dtype = eval(symbol( get(ini,"datatype") ))
end


function write_srm(f::Rawfile)
  ini = Inifile()
  set(ini, "size", string(f.size)[2:end-1] )
  set(ini, "datatype", string(f.dtype) )
  open(f.filename*f.extHeader,"w") do fd
    write(fd, ini)
  end
end

ndims(f::Rawfile) = length(f.size)
size(f::Rawfile) = f.size
size(f::Rawfile, dir::Integer) = f.size[dir]

function setindex!(f::Rawfile,x)
  f.size = size(x)
  f.dtype = eltype(x)
  open(f.filename*f.extRaw,"w") do fd
    write(fd, x)
  end
  write_srm(f)
end

function getindex(f::Rawfile)
  x = open(f.filename*f.extRaw,"r") do fd
    read(fd, f.dtype, f.size...)
  end
end


function getindex(f::Rawfile,::Colon,::Colon)
   f[]
end

function getindex(f::Rawfile,x::UnitRange,y)
  fd = open(f.filename*f.extRaw,"r")

  matrix = zeros(f.dtype, (length(x),length(y)))
  for l=1:length(y)
    seek(fd, ((y[l]-1)*f.size[1] + x[1] - 1 )*sizeof(f.dtype))
    matrix[:,l] = read(fd, f.dtype, length(x))
  end

  close(fd)
  matrix
end


function setindex!(f::Rawfile, A,::Colon,::Colon)
  f[] = A
end

function setindex!(f::Rawfile, A, x::UnitRange, y)
  if f.dtype != eltype(A); error("wrong datatype") end
  if length(x) != size(A,1); error("dimension missmatch") end

  open(f.filename*f.extRaw,"a+") do fd
    for l=1:length(y)
      seek(fd, ((y[l]-1)*f.size[1] + x[1] - 1 )*sizeof(f.dtype))
      write(fd, A[x,l])
    end
  end
end

end # module
