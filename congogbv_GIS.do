
*Can't get nice maps out of SPMAP; QGIS is giving me issues as well.

cd  "C:\Users\Koen\Dropbox (Personal)\PhD\Papers\CongoGBV\Shapefiles"

use "$dataloc\endline\MFS II Phase B Questionnaire de MénageVersion Terrain.dta",clear
keep gpsLatitude gpsLongitude
gen id = _n
save hh_gps, replace
export delimited using hh_gps.csv, datafmt replace


*https://www.stata.com/support/faqs/graphics/spmap-and-maps/

shp2dta using "codadmbndaadm2rgc20170711\cod_admbnda_adm2_rgc_20170711.shp", ///
	database("test") ///
	coordinates("testcoord") genid(id) replace

	use "C:\Users\Koen\Dropbox (Personal)\PhD\Papers\CongoGBV\Shapefiles\test", clear


	//spmap using "testcoord",  id(id)  ocolor(black)  osize(vthin)
 
 *lakes
	shp2dta using "lac_converted\Lac_a.shp", ///
	database("lakes") ///
	coordinates("lakes_coord") genid(id) replace

	use "lakes", clear
	keep if NOM1 == "Lac Tanganyika" | NOM1 == "Lac Kivu"
	//spmap using "lakes_coord",  id(id) ///      
	//fcolor(eggshell)  ocolor(dkgreen)  osize(thin) 



	ren id _ID

	merge 1:m _ID using "lakes_coord",keep(match)

	keep _ID _X _Y
	drop if missing(_X)
	save lakes, replace 

	use test
	keep if ADM1_FR == "Sud-Kivu"

	spmap using "testcoord",  id(id) ///      
	fcolor(eggshell)  ocolor(dkgreen)  osize(thick) ///
	poly(data("lakes") fcolor(blue))

	point(data("hh_gps")  x(gpsLongitude)  y(gpsLatitude) ///        
		size(*0.6)  fcolor(sienna)  ocolor(white) ///  
		osize(vvthin)) 


	poly(data("lakes") fcolor(blue))


