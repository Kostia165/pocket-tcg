extends Node
## Downloads card sprites from pokemondb on demand and caches them in user://sprites/.

const URL := "https://img.pokemondb.net/sprites/home/normal/%s.png"
const CACHE_DIR := "user://sprites/"
const SIZE := 160          # sprites are downscaled to this before caching
const MAX_PARALLEL := 4
const MAX_IN_MEMORY := 400

var _textures: Dictionary = {}  # slug -> Texture2D
var _waiting: Dictionary = {}   # slug -> Array[Callable]
var _queue: Array = []          # slugs to download, newest last
var _active := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)


## Calls `callback(texture)` once the sprite is available (immediately if cached).
func request(slug: String, callback: Callable) -> void:
	if _textures.has(slug):
		callback.call(_textures[slug])
		return
	var path := CACHE_DIR + slug + ".png"
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img:
			callback.call(_remember(slug, img))
			return
	if _waiting.has(slug):
		_waiting[slug].append(callback)
		if _queue.has(slug):  # still queued (not downloading yet): move it to the front
			_queue.erase(slug)
			_queue.append(slug)
		return
	_waiting[slug] = [callback]
	_queue.append(slug)
	_pump()


func _remember(slug: String, img: Image) -> Texture2D:
	if _textures.size() >= MAX_IN_MEMORY:
		_textures.clear()
	var tex := ImageTexture.create_from_image(img)
	_textures[slug] = tex
	return tex


func _pump() -> void:
	while _active < MAX_PARALLEL and not _queue.is_empty():
		var slug: String = _queue.pop_back()
		# Skip downloads nobody is waiting for any more (e.g. the page was changed).
		if not _waiting[slug].any(func(cb: Callable): return cb.is_valid()):
			_waiting.erase(slug)
			continue
		var http := HTTPRequest.new()
		add_child(http)
		http.request_completed.connect(_on_done.bind(slug, http))
		if http.request(URL % slug) != OK:
			http.queue_free()
			_waiting.erase(slug)
			continue
		_active += 1


func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, slug: String, http: HTTPRequest) -> void:
	http.queue_free()
	_active -= 1
	var callbacks: Array = _waiting.get(slug, [])
	_waiting.erase(slug)
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var img := Image.new()
		if img.load_png_from_buffer(body) == OK:
			img.resize(SIZE, SIZE, Image.INTERPOLATE_BILINEAR)
			img.save_png(CACHE_DIR + slug + ".png")
			var tex := _remember(slug, img)
			for cb in callbacks:
				if cb.is_valid():
					cb.call(tex)
	_pump()
