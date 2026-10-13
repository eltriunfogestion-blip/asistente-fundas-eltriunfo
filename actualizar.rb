# encoding: UTF-8
# Lee el catálogo público de lubricentroeltriunfo.com.ar y genera subir-a-netlify/index.html
require "json"; require "cgi"; require "base64"; require "date"; require "fileutils"; require "shellwords"

TIENDA = "https://lubricentroeltriunfo.com.ar"
BASE   = File.expand_path("..", __dir__)
ARCH   = __dir__
FOTOS  = File.join(ARCH, "fotos")
SALIDA = File.join(BASE, "subir-a-netlify")
[FOTOS, SALIDA].each { |d| FileUtils.mkdir_p(d) }

def bajar(url)
  `curl -sL --max-time 60 -A "Mozilla/5.0" #{Shellwords.escape(url)}`.force_encoding("UTF-8")
end

# ---------- Datos de cada funda que la tienda no tiene en forma ordenada ----------
# La clave es la que usa plantilla.html (lista MARCAS). Se reconoce el producto por el final de su link.
# Especial o universal se decide por el precio (ver ESPECIAL_DESDE). marca: universal de esa marca (nil = genérica).
# tras: "entero" | "dividido" | nil (la ficha no lo aclara)
CONFIG = {
  "universal"=>{slug:"fundas-asientos-autos-completa-3d01o", marca:nil, tras:"entero", pz:10, mat:"Símil cuero", n:"Fundas Asientos Autos Completa (Universal)"},
  "fordEnt" =>{slug:"fundas-asientos-autos-completa-ford-q0ali", marca:"Ford", tras:"entero", mat:"Ecocuero"},
  "fordRep" =>{slug:"fundas-asientos-autos-especial-repartida-ford-ecosport-focus-s5ugj", tras:"dividido", pz:13, mat:"Símil cuero + elastizado", logo:true, extra:"Respaldo y asiento trasero repartidos 1/3 – 2/3 del lado del acompañante."},
  "ranger"  =>{slug:"fundas-asientos-autos-completa-ford-ranger-16ky2", tras:"entero", mat:"Ecocuero", extra:"Versión Enteriza XL, para butacas más grandes."},
  "fiatEnt" =>{slug:"fundas-asientos-autos-fiat-completa-11iia", marca:"Fiat", tras:"entero", mat:"Ecocuero"},
  "mobi"    =>{slug:"fundas-asientos-fiat-mobi-6idoq", tras:"entero", mat:"Símil cuero", extra:"Apoyacabeza fijo y detalles bordados, como el original del Mobi."},
  "chevEnt" =>{slug:"fundas-asientos-completa-chevrolet-10j8j", marca:"Chevrolet", tras:"entero", mat:"Ecocuero"},
  "chevRep" =>{slug:"fundas-asientos-autos-especial-chevrolet-corsa-agile-meriva-nc27g", tras:"dividido", mat:"Símil cuero", extra:"Respaldo trasero repartido del lado del acompañante y asiento trasero entero.", logo:true},
  "celta"   =>{slug:"fundas-asientos-autos-especial-chevrolet-celta-c-abertura-1q6af", marca:"Chevrolet", tras:nil, mat:"Símil cuero", extra:"Con abertura en el respaldo delantero, para la palanca de rebatimiento del Celta 3 puertas."},
  "vwGol"   =>{slug:"fundas-asiento-completa-volkswagen-1v587", marca:"Volkswagen", tras:"entero", mat:"Ecocuero premium", logo:true},
  "vwBora"  =>{slug:"fundas-asientos-autos-especial-bora-vento-amarok-8zk5x", tras:"entero", mat:"Símil cuero", extra:"Modelo ancho, para butacas anchas.", logo:true},
  "vwSuran" =>{slug:"fundas-asientos-autos-completa-volkswagen-suran-fox-repartid-kab4g", tras:"dividido", mat:"Ecocuero", extra:"Respaldo trasero repartido al medio y asiento trasero entero."},
  "renEnt"  =>{slug:"fundas-asientos-renault-completa-1w6em", marca:"Renault", tras:"entero", mat:"Ecocuero"},
  "stepway" =>{slug:"fundas-asientos-autos-especial-stepway-1eyf3", tras:"dividido", mat:"Símil cuero", extra:"Respaldo trasero repartido del lado del acompañante."},
  "renAncha"=>{slug:"fundas-asientos-autos-especial-repartida-duster-fluence-alaskar-74cm8", tras:"entero", mat:"Símil cuero", pz:11, extra:"Modelo ancho, para butacas anchas.", logo:true},
  "kangoo"  =>{slug:"fundas-asientos-autos-especial-renault-kango-1gf8r", tras:"dividido", mat:"Símil cuero", extra:"Respaldo y asiento trasero repartidos del lado del acompañante."},
  "peuEnt"  =>{slug:"funda-cubre-asiento-peugeot-106-205-206-207-306-307-w74fc", marca:"Peugeot", tras:"entero", mat:"Ecocuero"},
  "partner" =>{slug:"fundas-asientos-autos-especial-peugueot-partner-repartida-1iqdk", tras:"dividido", mat:"Símil cuero", extra:"Respaldo y asiento trasero repartidos del lado del conductor.", logo:true},
  "toyota"  =>{slug:"funda-cubre-asiento-toyota-etios-yaris-bb4db", marca:"Toyota", tras:"entero", mat:"Ecocuero"},
}
# Nombres cortos para mostrar (si no está acá, se usa el nombre de la tienda)
ESPECIAL_DESDE = 50000   # desde este precio la funda es "especial"; por debajo, "universal"
NOMBRES = {
  "fordEnt"=>"Funda Ecocuero Ford Fiesta - Ka - Focus - Orion", "fordRep"=>"Fundas Especial Repartida Ford EcoSport - Focus",
  "fiatEnt"=>"Fundas Ecocuero Fiat Palio - Duna - Siena - Uno - 147", "chevEnt"=>"Funda Ecocuero Chevrolet Corsa - Classic - Agile - Astra",
  "chevRep"=>"Fundas Especial Repartida Chevrolet Corsa - Agile - Meriva", "vwGol"=>"Fundas Ecocuero VW Gol Trend - Voyage (con logo)",
  "vwBora"=>"Fundas Especial VW Bora - Vento - Amarok", "renEnt"=>"Fundas Ecocuero Renault Clio - Sandero - Mégane - R19",
  "stepway"=>"Fundas Especial Repartida Stepway - Duster - Captur", "renAncha"=>"Fundas Renault Ancha Enteriza (Duster - Fluence - Alaskan)",
  "peuEnt"=>"Funda Peugeot 106 - 205 - 206 - 207 - 306 - 307", "toyota"=>"Funda Toyota Etios - Yaris",
}

# ---------- 1. Lista de productos (todas las páginas de /productos/) ----------
links = []
(1..10).each do |pag|
  html = bajar("#{TIENDA}/productos/?page=#{pag}")
  nuevos = html.scan(%r{href="(https://lubricentroeltriunfo\.com\.ar/productos/[a-z0-9-]+/)"}).flatten.uniq - links
  break if nuevos.empty?
  links += nuevos
end
abort "No se pudo leer la tienda (¿hay internet?). No se cambió nada." if links.size < 10
puts "Productos en la tienda: #{links.size}"

# ---------- 2. Ficha de cada producto: precios, stock, cuotas, colores, foto ----------
def leer_producto(url)
  html = bajar(url)
  vj = html[/data-variants="([^"]*)"/, 1] or return nil
  v = JSON.parse(CGI.unescapeHTML(vj)) rescue (return nil)
  disp = v.select { |x| x["available"] }
  x = (disp.first || v.first)
  nombre = CGI.unescapeHTML(html[/<h1[^>]*>\s*([^<]+?)\s*<\/h1>/m, 1].to_s).strip
  cuotas = 1
  (JSON.parse(x["installments_data"].to_s) rescue {}).each_value do |plan|
    plan.each { |n, d| cuotas = [cuotas, n.to_i].max if d["without_interests"] }
  end
  { "url"=>url, "slug"=>url[%r{/productos/([^/]+)/}, 1], "n"=>nombre, "p"=>x["price_number"], "c"=>x["compare_at_price_number"],
    "tr"=>x["price_with_payment_discount_short"].to_s.gsub(/[$.\s]/, "").sub(",", ".").to_f.round,
    "q"=>cuotas, "disp"=>!disp.empty?, "col"=>disp.map { |y| y["option0"] }.compact.uniq,
    "img"=>"https:" + x["image_url"].to_s.gsub("\\/", "/").sub("-1024-1024", "-480-0") }
end

def foto(p)
  f = File.join(FOTOS, "#{p["slug"]}.webp")
  system("curl", "-sL", "--max-time", "30", "-A", "Mozilla/5.0", "-o", f, p["img"]) unless File.size?(f)
  File.size?(f) ? "data:image/webp;base64," + Base64.strict_encode64(File.binread(f)) : nil
end

puts "Leyendo fichas…"
prods = links.map { |u| leer_producto(u) }.compact
abort "No se pudieron leer las fichas. No se cambió nada." if prods.size < 10

# ---------- 3. Fundas conocidas, fundas nuevas y accesorios ----------
es_funda = ->(p) { p["n"] =~ /funda|cubre ?asiento|cubreasiento/i && p["n"] !~ /volante/i }
fundas, accesorios, nuevos, sin_stock = {}, [], {}, []
# Modelos de plantilla.html, para asignar solas las fundas nuevas que nombren un modelo
plantilla = File.read(File.join(ARCH, "plantilla.html"), encoding:"UTF-8")
marcas = {}
plantilla[/const MARCAS = \{(.*?)\n\};/m, 1].to_s.scan(/"([^"]+)":\[(.*?)\]\s*(?:,\s*\n|\n|$)/m).each do |marca, cuerpo|
  marcas[marca] = cuerpo.scan(/m:"([^"]+)"/).flatten
end
norm = ->(s) { s.to_s.downcase.tr("áéíóúü", "aeiouu") }

prods.each do |p|
  unless p["disp"]
    sin_stock << p["n"]; next
  end
  cat = p["p"].to_f >= ESPECIAL_DESDE ? "especial" : "universal"
  base = { n:p["n"], p:p["p"], c:p["c"], tr:p["tr"], q:p["q"], u:p["url"].sub(TIENDA, ""), img:foto(p) }
  clave, cfg = CONFIG.find { |_, c| c[:slug] == p["slug"] }
  if clave
    fundas[clave] = base.merge(cfg.reject { |k, _| k == :slug }).merge(n:(cfg[:n] || NOMBRES[clave] || p["n"]), col:p["col"], cat:cat)
  elsif es_funda.(p)
    clave = "t_" + p["slug"].gsub(/[^a-z0-9]/, "_")
    nn = norm.(p["n"])
    lista = []
    marcas.each do |marca, mods|
      mods.each do |m|
        palabra = norm.(m).sub(/\s*\(.*\)/, "")
        lista << [marca, m] if nn =~ /(^|[^a-z0-9])#{Regexp.escape(palabra)}([^a-z0-9]|$)/
      end
    end
    tras = p["n"] =~ /repartid/i ? "dividido" : p["n"] =~ /enteriz/i ? "entero" : nil
    marca = lista.map(&:first).uniq.size == 1 ? lista[0][0] : nil
    fundas[clave] = base.merge(tras:tras, mat:(p["n"] =~ /ecocuero/i ? "Ecocuero" : "Símil cuero"), col:p["col"], cat:cat, marca:(cat == "universal" ? marca : nil))
    nuevos[clave] = lista unless lista.empty?
    puts "  Funda nueva: #{p["n"]} → #{lista.empty? ? "NO nombra un modelo conocido: agregarla a mano en plantilla.html" : lista.map { |a| a.join(" ") }.join(", ")}"
  else
    accesorios << base
  end
end
faltan = CONFIG.keys - fundas.keys
puts "  Sin stock o no encontradas (no se muestran): #{faltan.join(", ")}" unless faltan.empty?

# ---------- 4. Armar la página (solo se reescribe si algo cambió) ----------
datos = "const FUNDAS=" + JSON.generate(fundas) + ";\nconst ACCESORIOS=" + JSON.generate(accesorios) + ";\nconst NUEVOS=" + JSON.generate(nuevos) + ";"
t = plantilla.sub("__LOGO__", "data:image/webp;base64," + Base64.strict_encode64(File.binread(File.join(ARCH, "logo.webp"))))
t = t.sub("__DATA__") { datos }
salida = File.join(SALIDA, "index.html")
previa = File.exist?(salida) ? File.read(salida, encoding:"UTF-8") : ""
fecha_previa = previa[/const ACTUALIZADO = "([^"]+)"/, 1]
if fecha_previa && t.sub("__FECHA__", fecha_previa) == previa
  puts "\nSin cambios: precios, stock y productos siguen iguales que el #{fecha_previa}. No hace falta publicar."
else
  File.write(salida, t.sub("__FECHA__", Date.today.strftime("%d/%m/%Y")))
  puts "\nListo: #{fundas.size} fundas y #{accesorios.size} accesorios, precios del #{Date.today.strftime("%d/%m/%Y")}."
end
