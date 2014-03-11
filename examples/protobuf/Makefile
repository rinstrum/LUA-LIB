PROTO_FILE=messages.proto

all:

# Which language to generate protobuf files for.
# The compiler can produce multiple outputs in one go if you use multiple languages.
messages.pb.cc messages.pb.h:
	protoc --cpp_out=. $(PROTO_FILE)
Messages.java:
	protoc --java_out=. $(PROTO_FILE)
messages_pb2.py:
	protoc --python_out=. $(PROTO_FILE)

clean:
	rm -f messages.pb.cc messages.pb.h Messages.java messages_pb2.py
