/**
 *  MOSAIIC Model - 16 octobre 2015
 *  Author: patricktaillandier
 *  Description: fusion avec la version de Guillaume
 *  Dernière modif : 
 * 	date : 10 juillet 2016
 * 	auteur : patrick
 * 	travail : optimisation openmole
 * 
 */

 
model RoadTrafficComplex

global {   
	bool axes_majeurs <- false ;
	bool is_openmole <- true;
	int nb_people_alea <- 18147 ;
	string classique <- "sc classique";
	string aleatoire_total <- "alea_alea"; // pour test <- à salongueurns doute enlever ++ enlever dans string type_simulation ++ enlever dans match aleatoire_total
	string longueur <- "alea longueur";
	string ponderation <- "alea ponderation";
	string type_simulation <- "sc classique" among:[classique, aleatoire_total, longueur, ponderation] ;
	
	file shape_file_roads  <- axes_majeurs ? file("../includes/roads_7200_pm_ok_v4_corrige_Axes.shp")  : file("../includes/roads_7200_pm_ok_v4_corrige.shp") ;
	file shape_file_nodes  <-  axes_majeurs ?file("../includes/nodes_7200_pm_ok_v1.shp"): file("../includes/nodes_7200_pm_ok_v1.shp");
	file shape_urgence  <-  axes_majeurs ?file ("../includes/nodes_7200_pm_ok_v1_selec_sorties_Axes.shp") : file ("../includes/nodes_7200_pm_ok_v1_selec_sorties.shp") ;
	
	geometry shape <- envelope(shape_file_roads);
	graph road_network_speed;  
	graph road_network_custom;  
	
	map<road,float> general_speed_map_speed;
	
	float proba_fous <- 0.0;
	
	float proportion_speed_lane <- 1.0;
	float proportion_speed <- 0.25;
	float proportion_distance <- 0.25;
	
	float min_embouteillage_people_creation <- 30.0;
	float min_embouteillage_people_destruction <- 20.0;
	float speed_coeff_traffic_jam <- 3.0;
	float time_to_consider_traffic_jam <- 2#mn;
	float distance_see_traffic_jams <- 500.0; // changé, initialement 500m. 
	
	float accepted_evacuation_distance <- 20.0; //distance d'un point d'évacuation à partir de laquelle on est "safe" -> l'agent est "tué"
	
	
	int time_accident <- 1;
	float prop_agent_evacuation <- 1.0;
	
	int nb_agents_in_traffic_jam update:people count (each.in_traffic_jam);
	int nb_driving_agent update:people count (each.real_speed > 1#km /#h);
	int nb_agent_speed_30 update:people count (each.real_speed < 30#km /#h); 
	int nb_agent_speed_zero update:people count (each.real_speed < 1#km /#h);
	int nb_traffic_signals_green update:node_ count (each.is_green);
	int nb_agent_update  update:length(people);
	
	float traffic_jam_length <- 0.0 update: sum(embouteillage collect (each.shape.perimeter));
	
	int traffic_jam_nb_roads <- 0 update: length(embouteillage);
	
	float mean_real_speed <- 0.0 update: mean((people) collect (each.real_speed)) #h/#km;
	
	list<node_> traffic_signals;
	list<node_> connected_nodes;
	list<road> real_roads;
	
	float min_length <- 0.0;
	
 	list<node_> vertices;
	
	float proba_avoid_traffic_jam_global <- 0.8;
	float proba_know_map <- 0.5; // initialement à 0.5
	int nb_avoid_max <- 3;
	
	file file_ssp_speed;
	
	int nb_path_recompute;
	
	list<people> people_moving ;
	
	float coeff_nb_people <- 1.0; ////// ICI 
	
	float max_priority;
	
	bool use_traffic_lights <- true;
	
	float tps_debut <-machine_time;
	
	string simulation_id <- ""+axes_majeurs+"_"+type_simulation +"_"+ proba_fous + "_" + use_traffic_lights + "_"+  seed;
	string simulation_id_openmole <- "am-"+axes_majeurs+"_sc-"+type_simulation +"_fou-"+ proba_fous + "_tl-" + use_traffic_lights + "_";
	
	list<int> evacuation_steps <- [5,10,15,20,25,30,35,40,45,50,55,60,65,70,75,80,85,90,95,99,100];
	int evacuation_steps_index <- 0;
	
	int nb_people_init;
	float percentage_evac <- 0.0 update: 100.0 * (1  - length(people)/nb_people_init);
	
	// ICIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII SAVE 
	
	
	
	reflex add_evacuation_time when: is_openmole  {
		loop while:(evacuation_steps_index < length(evacuation_steps)) and (percentage_evac > evacuation_steps[evacuation_steps_index]) {
			save [axes_majeurs, type_simulation, use_traffic_lights,proba_fous,seed,cycle,percentage_evac] type: "csv" to: simulation_id_openmole + "evacuation_time.csv";
		
			evacuation_steps_index <- evacuation_steps_index + 1;
		}
		
	
		
	}
	reflex save_classic_openmole when: is_openmole and every(10) {
		save [axes_majeurs, type_simulation, use_traffic_lights,proba_fous,seed,cycle,length(people),mean_real_speed] type: "csv" to: simulation_id_openmole + "data.csv";
		
		
	}

	
	
	reflex save_usage_route_openmole when: is_openmole and (time = 2 or every(300)) {
		ask road {
			if  (nb_personnes > 0) {
				temps_moy <- temps_tot / nb_personnes ;
			 } else {
                  temps_moy <- 0.0; //j'ai ajouté ça pour plus de clarté
             }
             list_temps_moy << temps_moy;
             list_nb_people << nb_personnes;
             nb_personnes <- 0;
             temps_tot <- 0;
             
             
        }
        //save road type:"shp" to:chemin + "/shp_route/shape_usage_route_" + time + ".shp" crs: "EPSG:2154" with:[temps_moy::"Tps_Moy", nb_personnes::"people"] ;				
		if (time = 3#h) {
			ask road {
				string txt_pp <- ""+axes_majeurs+","+ type_simulation + ","+use_traffic_lights+","+ proba_fous + ","+string(seed)+","+id + "," + highway;
				loop v over: list_nb_people {
					txt_pp <- txt_pp+ ","+ v  ;
				}
				save txt_pp to: simulation_id_openmole + "people_per_road.csv";
				
				string txt_tm <-""+axes_majeurs+","+ type_simulation + ","+use_traffic_lights+","+ proba_fous + ","+string(seed)+","+id + "," + highway + "," + temps_tot_global ;
				loop tm over: list_temps_moy {
					txt_tm <- txt_tm+ ","+ tm  ;
				}
				save txt_tm to: simulation_id_openmole + "temps_per_road.csv";
				//save temps_tot_global to: "temps_per_road.csv";
			}
		}
	}
	
	

	
	//****** UTILISER POUR L'OPTIMISATION DU MODELE *****
	/*float t1;
	float t2;
	float t3;
	float t4;5000
	float t5;
	float t6;
	float t7;*/
	
	//****************************************
	string chemin <- "sorties/tf_" + use_traffic_lights + "_fou_" + proba_fous + "_" + "coefpeople_" + coeff_nb_people + "_" + #now ;
	init { 
		save "axes_majeurs, type_simulation, use_traffic_lights,proba_fous,seed,id,highway,temps_tot_global,temps_per_road" to: simulation_id_openmole + "temps_per_road.csv";
		save "axes_majeurs, type_simulation, use_traffic_lights,proba_fous,seed,id,highway,people_per_road" to: simulation_id_openmole + "people_per_road.csv";
		save "axes_majeurs, type_simulation, use_traffic_lights,proba_fous,seed,cycle,nb_people,mean_real_speed" to: simulation_id_openmole + "data.csv";
		save "axes_majeurs, type_simulation, use_traffic_lights,proba_fous,seed,cycle,percentage_evac" to: simulation_id_openmole + "evacuation_time.csv";
		
		//file folder <- new_folder(chemin) ; 
		create evacuation_urgence from: shape_urgence {id <- int(self);}
		//save evacuation_urgence type:"shp" to:"evac.shp" with: [id::"ID"];
		
		create node_ from: shape_file_nodes with:[is_traffic_signal::(string(read("type")) = "traffic_signals"), is_crossing :: (string(read("crossing")) = "traffic_signals")];
		loop pt over: remove_duplicates(node_ collect (each.location)) {
			list<node_> nds <- node_ overlapping pt;
			nds >> one_of(nds);
			ask nds {
				do die;
			}
		}
		ask evacuation_urgence {
			noeud_evacuation <- node_ closest_to self;
		}

		write "etape 1";
		create road from: shape_file_roads with:[nb_agents::int(read("NB_CARS")), name::string(read("name")),highway::string(get("highway")),junction::string(read("junction")),lanes::int(read("lanes")), maxspeed::float(read("maxspeed")) #h/#km, oneway::string(read("oneway")), lanes_forward ::int (get( "lanesforwa")), lanes_backward :: int (get("lanesbackw")), priority::float((get("priority"))), target_evacuation ::int(get("evacuation"))] {
			if maxspeed <= 0 {maxspeed <- 50 #km/#h;}
			if lanes <= 0 {lanes <- 1;}
			capacite_max <- 1+ int(lanes * shape.perimeter/(5.0));
			min_traffic_jam_people_destroy <- int(max([3,min([capacite_max / 2.0, min_embouteillage_people_destruction])]));
			min_traffic_jam_people_creation <- int( max([3,min([capacite_max/2.0, min_embouteillage_people_creation])]));
			geom_display <- (shape + (2.5 * lanes));
			max_embouteillage_vitesse <- maxspeed / speed_coeff_traffic_jam;
			//id <- int(self);
		}	
		//create danger from: file("../includes/seveso_lubrizol_1500m.shp") ;
		write "etape 2";
		ask road overlapping first(danger) {
			danger_area <- true;
		}
		real_roads <- road where (each.shape.perimeter > min_length);
		general_speed_map_speed <- road as_map (each::(each.shape.perimeter / each.maxspeed * (each.danger_area ?  100 : 1))); 
		
		
		road_network_speed <-  ((as_driving_graph(road, node_))  with_weights general_speed_map_speed) use_cache false;
		road_network_custom <- (as_driving_graph(road, node_)) use_cache false;
		write "etape 3";
		ask road {
			neighbours <- node_ at_distance distance_see_traffic_jams;
		}
		vertices <- list<node_>(road_network_speed.vertices);
		loop i from: 0 to: length(vertices) - 1 {
			vertices[i].id <- i; 
		}
		list<string> roads_importance <- ["service","residential", "unclassified",  "tertiary_link", "tertiary",  "secondary_link", "secondary", "primary_link", "primary", "trunk_link", "trunk", "motorway_link", "motorway"];
		write "etape 4";
		ask node_ {
			roads_in <- remove_duplicates(roads_in);
			roads_out <- remove_duplicates(roads_out);
			if (length(roads_in) > 1) {
				priority_roads <- roads_in where (road(each).junction = "roundabout");
				if (empty(priority_roads)) {
					int max_importance <- roads_in max_of (roads_importance index_of road(each).highway);
					priority_roads <- roads_in where ((roads_importance index_of road(each).highway) = max_importance);
				}
			}
			
		}
		connected_nodes <- node_ where (not empty(each.roads_in) and not empty(each.roads_out));
		write "etape 5";
		do init_traffic_signal;
		do fill_matrix;
		switch type_simulation {
			match classique {
				ask road {
					int nb <- int(0.5 + nb_agents/coeff_nb_people);
					if (nb > 0) {
						ask world{do create_people_road(myself,nb);} 
					}
				}	
			}
			match aleatoire_total {
				list<float> poids <- road collect (each.shape.perimeter / each.shape.perimeter);
				loop times: nb_people_alea {
					road the_road <- road[rnd_choice(poids)];
					ask world{do create_one_people_road(the_road, any_location_in(the_road), rnd(the_road.lanes)) ;}
				}
			}
			match longueur {
				list<float> poids <- road collect (each.shape.perimeter);
				loop times: nb_people_alea {
					road the_road <- road[rnd_choice(poids)];
					ask world{do create_one_people_road(the_road, any_location_in(the_road), rnd(the_road.lanes)) ;}
				}
			}
			match ponderation {
				list<float> poids <- road collect (each.shape.perimeter * each.maxspeed*each.lanes);
				loop times: nb_people_alea {
					road the_road <- road[rnd_choice(poids)];
					ask world{do create_one_people_road(the_road, any_location_in(the_road), rnd(the_road.lanes)) ;}
				}
			}
		}  
		nb_agent_update <- length(people);  
		write "etape 6";
		if (sum(road collect each.priority) = 0) {
			do compute_road_priority;
		}
		write "etape 7";
		nb_people_init <- length(people);
		 
		// PRIORITÉS
		//save priority and target_evacuation of roads in the shapefile roads_7200_pm_ok_v3
		//priorités
		/*ask road {maxspeed <- maxspeed #km/#h;}
	is_openmole
	sss	save road to: ("../includes/roads_7200_pm_ok_v3.shp") type: "shp"
		with:[nb_agents::"NB_CARS", name::"name",highway::"highway",junction::"junction",lanes::"lanes", maxspeed ::"maxspeed", oneway::"oneway", lanes_forward :: "lanesforwa", lanes_backward :: "lanesbackw", priority::"priority", target_evacuation::"evacuation"];
		*/
	}
	
	reflex scnerio_evac when: cycle = time_accident  {
		ask (prop_agent_evacuation * length(people)) among people {
			target_node <- nil;
			color_behavior <- #red;
			targets <- [];
			current_path <- nil;
			size <- 10;
		}
	}
	
	
	action fill_matrix {
		file_ssp_speed <- csv_file("shortest_paths_speed_3.csv",";");
	}
	
	action create_one_people_road(road a_road, point pt, int i) {
		bool est_fou <- flip(proba_fous);
		create people  { 
			speed <- 50 #km /#h ;
			real_speed <- 50 #km /#h ;
			vehicle_length <- 4.0 + rnd(1.0) #m;
			right_side_driving <- true;
			proba_lane_change_up <- est_fou ? 1.0 : 0.8 ;// 0.5 + (rnd(500) / 500);
			proba_lane_change_down <- est_fou ? 1.0 : 1.0;//0.7+ (rnd(300) / 500);
			location <- pt;
			current_lane <- i;
			init_rd <- a_road;
			security_distance_coeff <- est_fou ? 0.5 : 2 * (1.5 - rnd(1.0)); //  
			proba_respect_priorities <- est_fou ? 0.5 : 1.0;
			proba_respect_stops <- est_fou ? [0.5] : [1.0]; // POURQUOI CROCHETS ? 
			proba_block_node <- est_fou ? 0.01 : 0.0;
			proba_use_linked_road <- 0.0;
			max_speed <- est_fou ? 150 : 150 #km/#h;
			max_acceleration <- 1000.0;//(12 + rnd(500) / 100) #km/#h;
			speed_coeff <- est_fou ? 2.0 : 1.2 - (rnd(400) / 1000);
			proba_avoid_traffic_jam <- proba_avoid_traffic_jam_global;
		}
	}
	
	action create_people_road(road a_road, int nb) {
		list<point> pts <- points_on(a_road,a_road.shape.perimeter/(nb/a_road.lanes));
		loop pt over: pts {
			loop i from: 0 to: a_road.lanes -1 {
				do create_one_people_road(a_road,pt,i);
			}
		}
	}
	
	action init_traffic_signal { 
		traffic_signals <- node_ where each.is_traffic_signal ;
		ask traffic_signals {
			stop << [];
		}
		
		list<list<node_>> groupes <- list<list<node_>>(traffic_signals simple_clustering_by_distance 50.0); 
		loop gp over: groupes {
			int cpt_init <- rnd(100);
			bool green <- flip(0.5);
			
			if (length(gp) = 1) {
				ask (first(gp)) {
					if (use_traffic_lights) {
						if (green) {do to_green;} 	
						else {do to_red;}
					} 
					do compute_crossing;
				}	
			} else {
				point centroide <- mean (gp collect each.location);
				int angle_ref <- centroide direction_to first(gp).location;
				bool first <- true;
				float ref_angle <- 0.0;
				loop ns over: gp {
					bool green_si <- green;
					int ang <- abs((centroide direction_to ns.location) - angle_ref);
					if (ang > 45 and ang < 135) or  (ang > 225 and ang < 315) {
						green_si <- not(green_si);
					}
					ask ns {
						counter <- cpt_init;
						if (use_traffic_lights) {
							if (green_si) {do to_green;} 	
							else {do to_red;}	
						}
						if (not empty(roads_in)) {
							if (is_crossing or length(roads_in) >= 2) {
								if (first) {
									list<point> pts <- road(roads_in[0]).shape.points;
									float angle_dest <- float( last(pts) direction_to road(roads_in[0]).location);
									ref_angle <-  angle_dest;
									first <- false;
								}
								loop rd over: roads_in {
									list<point> pts <- road(rd).shape.points;
									float angle_dest <- float(last(pts) direction_to rd.location);
									
									float ang <- abs(angle_dest - ref_angle);
									if (ang > 45 and ang < 135) or  (ang > 225 and ang < 315) {
										add road(rd) to: ways2;
									}
								}
							} else {do compute_crossing;}
						}
					}	
				}
			}
		}
		ask traffic_signals {
			loop rd over: roads_in {
				if not(rd in ways2) {
					ways1 << road(rd);
				}
			}
		} 
	}
		
	action compute_road_priority {
		map<list<node_>,float> nodes2dist <- [];
		ask road {
			priority <- 999999999.9;
			loop i from: 0 to: length(evacuation_urgence) - 1 {
				evacuation_urgence e <- evacuation_urgence[i];
				if (e.noeud_evacuation = target_node) {
					priority <- 0.0;
					target_evacuation <- i;
					break;
				} 
				path p <-  path_between(road_network_speed, target_node, e.noeud_evacuation);
				if (p != nil and p.shape != nil) {
					float dist <- p.shape.perimeter;
					if (dist < priority) {
						priority <- dist;
						target_evacuation <- i;
					}
				}
			}
		}
	}
	
	
	list<node_> nodes_for_path (node_ source, node_ target, file ssp){
		list<node_> nodes <- [];
		int id <- source.id;
		int target_id <- target.id;
		int cpt <- 0;
		loop while: id != target_id {
			nodes << node_(vertices[id]);
			id <- int(ssp[target_id, id]);
			cpt <- cpt +1;
			if (id = -1 or cpt > 50000) {
				return list<node_>([]);
			}
		}
		nodes<<target;
		return nodes;
	}
	
	
	reflex general_dynamic {
	//	float t <- machine_time;
		
		ask traffic_signals {
			do dynamic_node;
		}
		//t1 <- t1 + machine_time - t;
		//t <- machine_time;
		if (every(5)) {
			ask real_roads {
				do dynamic_road;
			}	
		}
		//t2 <- t2 + machine_time - t;
		//t <- machine_time;
		
		ask people where (each.target_node = nil ){
			do choose_target_node;
		}
	//	t3 <- t3 + machine_time - t;
	//	t <- machine_time;
		
		ask people where ((each.current_path = nil or each.recompute_path or each.final_target = nil)and each.target_node != nil) {
			 do choose_a_path; 
			 if (final_target = nil) {
			 	if (current_road != nil) {
					ask road(current_road) {
						do unregister(myself);
					}
				}
				do die;
			 }
		}
	//	t4 <- t4 + machine_time - t;
	//	t <- machine_time;
		
		people_moving <- (people where (each.current_path != nil and each.final_target != nil ));
		
		ask people_moving {
			val_order <- (road(current_road).priority * 1000000 - 10000 * segment_index_on_road + distance_to_goal);
		}
		people_moving <- people_moving sort_by each.val_order;
	//	t5 <- t5 + machine_time - t;
	//	t <- machine_time;
		int cpt <- 0;
		ask people_moving{
			order <- cpt;
			do driving;
			cpt <- cpt + 1;
		}
		
		//t6 <- t6 + machine_time - t;
	//	t <- machine_time;
		//ask people where (each.target_node != nil and (each.location distance_to each.target_node.location < 10)){
		ask people where (each.target_node != nil) {
			if (evacuation_urgence first_with ((each distance_to self) < accepted_evacuation_distance)) != nil{
				if (current_road != nil) {
					ask road(current_road) {
						do unregister(myself);
					}
				}
				do die;	
			}
		}
	//	t7 <- t7 + machine_time - t;
	}
	
	//****** UTILISER POUR L'OPTIMISATION DU MODELE *****
	/*reflex info when: every(60)  { 
		write "\n ******** " + cycle + " ********";
		write "temps node : " + t1/1000;
		write "temps routes : " + t2/1000;
		write "temps choose target : " + t3/1000;
		write "temps choose path : " + t4/1000;
		write "temps tri : " + t5/1000;
		write "temps driving : " + t6/1000;
		write "temps arriver objectif : " + t7/1000;
		write "nb people :" + length(people) ;
		write "nb people driving :" +  nb_driving_agent ;
	}*/
	
	
	//****************************************
		
	
	/*reflex end when: length(people) = 0  { 
		do pause;
	}*/
} 


	
species node_ skills: [skill_road_node] {
	bool is_traffic_signal;
	int counter ;
	rgb color_centr; 
	rgb color_fire;
	float centrality;	
	bool is_blocked <- false;
	bool is_crossing;
	list<road> ways1;
	list<road> ways2;
	bool is_green;
	int time_to_change <- 60;
	list<road> neighbours_tj;
	int pb_start <- 0;
	int pb_end <- 0;
	int id;
	
	action compute_crossing{
		if (is_crossing and not(empty(roads_in))) or (length(roads_in) >= 2) {
			road rd0 <- road(roads_in[0]);
			list<point> pts <- rd0.shape.points;						
			float ref_angle <-  float( last(pts) direction_to rd0.location);
			loop rd over: roads_in {
				list<point> pts2 <- road(rd).shape.points;						
				float angle_dest <-  float( last(pts2) direction_to rd.location);
				float ang <- abs(angle_dest - ref_angle);
				if (ang > 45 and ang < 135) or  (ang > 225 and ang < 315) {
					add road(rd) to: ways2;
				}
			}
		}
	}
	
	action to_green {					
		stop[0] <-  ways2 ;
		color_fire <- rgb("green");
		is_green <- true;
	}
	
	action to_red {							
		stop[0] <- ways1;
		color_fire <- rgb("red");
		is_green <- false; 
	} 
	action dynamic_node {
		if (use_traffic_lights) { 
			counter <- counter + 1;
			
		 	if (counter >= time_to_change) { 	/// A REMETTRE SI ON VEUT DES FEUX
				counter <- 0;
				if is_green {do to_red;}
				else {do to_green;}
			}  	
		}
	}
	
	aspect base {    
		if (is_traffic_signal) {	
			draw circle(5) color: color_fire;
		} else {
			draw square(4) color: rgb("magenta");
		}
	} 
	
}

species danger { 
	aspect base {
		draw shape border: #orange color: #orange ;
	}
}

species road skills: [skill_road] { 
	int id;
	string oneway;
	geometry geom_display;
	bool is_blocked <- false;
	embouteillage embout_route <- nil;
	int nb_people <- 0;
	int nb_people_tot <- 0;
	int nb_agents ;
	bool danger_area <- false;
	
	int lanes_backward;
	int lanes_forward;
	float priority;
	int target_evacuation <- -1;
	
	string junction;
	
	float max_embouteillage_vitesse;
	bool traffic_jam <- false;
	list<people> bloques <- [];
	int capacite_max ;
	float nb_bloques <- 0.0;
	int min_traffic_jam_people_destroy;
	int min_traffic_jam_people_creation;
	
	road next_linked_road;
	string highway;
	list<node_> neighbours;
	
	int temps_tot;
	int temps_tot_global;
	int nb_personnes;
	int nb_personnes_tot;
	int nb_personnes_time;
	float temps_moy;
	
	list<float> list_temps_moy;
	list<int> list_nb_people;
	
	
	aspect carto {
		if highway = "trunk" or highway="trunk_link" or highway = "motorway" or highway = "motorway_link" {draw (shape + 3) border: #black color: #red;}
		else if highway = "primary" or highway="primary_link"{draw (shape + 2) border: #black color: #orange;}
		else if highway = "secondary" or highway="secondary_link" {draw (shape + 1) border: #black color: #yellow;}
		else {draw shape color: #black end_arrow: 1; }
	}
	aspect pp {
		draw shape color: #black ; 
		//draw (""+int(self)+" -> "+length(all_agents)) color: #black size: 10; 
	}
	
	action dynamic_road {
		nb_people <- length(all_agents);
		if (embout_route != nil) {
			bloques <- list<people>(nb_people = 0 ? [] : all_agents where (people(each).real_speed < max_embouteillage_vitesse));
			nb_bloques <- length(bloques) + 0.0;// /capacite_max ;
			if(nb_bloques < min_traffic_jam_people_destroy) {
				do maj_emboutillage_destruction;	
			} else if every(3) {
				do maj_embouteillage;
			}
		} else {
			if (nb_people > min_traffic_jam_people_creation) {
				bloques <- list<people>(nb_people = 0 ? [] : all_agents where (people(each).real_speed < max_embouteillage_vitesse));
				nb_bloques <- length(bloques) + 0.0;// /capacite_max ;
			
				if (nb_bloques > min_traffic_jam_people_creation) {
					do maj_emboutillage_creation;
				}	
			}
		}
		
	}
	
	action maj_emboutillage_destruction {
		ask embout_route {
			loop pb over: personnes_bloquees {
				pb.in_traffic_jam <- false;
			}
			do die;
		}
		ask neighbours {
			neighbours_tj >> myself;
		}
		embout_route <- nil;
		traffic_jam <- false;
	}
	
	action maj_emboutillage_creation {
		create embouteillage returns: eb with: [personnes_bloquees::bloques,route_concernee::self, shape::shape+5.0];
		embout_route <- first(eb);
		traffic_jam <- true;
		loop pb over: bloques {
			pb.in_traffic_jam <- true;
		}
		ask embout_route{
			personnes_bloquees<-myself.bloques;
		}
		
	}
	action maj_embouteillage {
		ask embout_route{
			loop pb over: personnes_bloquees {
				pb.in_traffic_jam <- false;
			}
			personnes_bloquees<-myself.bloques;
			loop pb over: personnes_bloquees {
				pb.in_traffic_jam <- true;
			}
		}	
	}
	
	
}

species embouteillage {
	list<people> personnes_bloquees;
	road route_concernee;
	float counter <- 0.0 update: counter + step;
	bool real_before <- false;
	bool real <- false ; 
	
	reflex maj_neighbours{
		if (cycle < 10) {counter <- 5#mn;}
		real_before <- real;
		real <- counter > time_to_consider_traffic_jam;
		if (real and not real_before) {
			counter <- 0.0;
			ask route_concernee.neighbours {
				neighbours_tj << myself.route_concernee;
			}
		} 
	}
	action maj_forme{
		shape <- polyline(personnes_bloquees collect each.location);
	}
	
	
	aspect base_width { 
		draw shape + 5.0 color: real ? #red : #green;
	}
	
}

species evacuation_urgence {
	node_ noeud_evacuation ;
	int id;
	aspect default {
		draw circle (10) color: #orange;
	}
}

species point_fuite {
	aspect default {
		draw circle (10) color: #pink;
	}
}
	
species people skills: [advanced_driving] schedules: [] { 
	rgb color <-rnd_color(255) ;
	rgb color_behavior <-#yellow;
	int size <- 8;
	bool in_traffic_jam <- false;
	node_ target_node;
	list<road> roads_traffic_jam;
	
	bool is_stopped <- false;
	bool recompute_path <- false;
	bool to_delete <- false;
	float proba_avoid_traffic_jam;
	node_ current_node;
	bool mode_avoid <- false;
	bool mode_fuite <- false;
	bool ma_premiere_route <- true ;
	int cpt_avoid <- 0;
	road init_rd;
	
	float val_order;
	
	int order;
	
	int temps_passe <- 0 ;  //update: temps_passe +1;
	
	
	action choose_target_node  {
		if cycle >= time_accident {
			//target_node <- (evacuation_urgence with_min_of (each distance_to self)).noeud_evacuation;
			target_node <- evacuation_urgence[road(current_road).target_evacuation].noeud_evacuation;
			if (target_node = nil) {
				if (current_road != nil) {
					ask road(current_road) {
						do unregister(myself);
					}
				}
				do die;
			}
		}
		else {
			target_node <- one_of(connected_nodes);
		}
		if(location distance_to target_node.location < accepted_evacuation_distance){
			if (current_road != nil) {
				ask road(current_road) {
					do unregister(myself);
				}
			}
			do die;
		}	
	}
	
	
	
	action choose_a_path  { 
		current_node <- nil;
		if (init_rd != nil) {
			if (cycle > 2 or (init_rd distance_to self > 0.5) or (init_rd.target_node distance_to self < 0.5) ) {
				if ((init_rd.target_node distance_to self < 0.5) )
				{
					current_node <- node_(init_rd.target_node);
				}
				init_rd <- nil;
				
			} else {
				current_node <- node_(init_rd.target_node); 
			}
		}
		if (current_node = nil) {
			if (current_road != nil) {
				current_node <-node_([road(current_road).source_node, road(current_road).target_node] with_min_of (each distance_to self));
			} else {
				current_node <- (node_ at_distance 50) closest_to self;
			}
			
		}
		if (recompute_path) {
			do recomputing_path(general_speed_map_speed);
			recompute_path <- false;
		} else {
			list<node_> nodes <- world.nodes_for_path(current_node,target_node,file_ssp_speed);
			if (init_rd != nil) {
				add node_(init_rd.source_node) to: nodes at: 0;
			}
			if (length(nodes) > 1) {current_path <- path_from_nodes(graph: road_network_speed, nodes: nodes);}
			 
			if (current_path = nil) {
				if (init_rd != nil) {
					current_path <- compute_path(graph: road_network_speed, target: target_node, on_road: init_rd);
				} else {
					current_path <- compute_path(graph: road_network_speed, target: target_node);
				}
				nb_path_recompute <- nb_path_recompute + 1;	
			}
			if (current_path = nil) {
				if (current_road != nil) { 
					ask road(current_road) {
						do unregister(myself);
					}
				}
				do die;
			} else {
				if flip(proba_avoid_traffic_jam) and not empty(roads_traffic_jam) and length(current_node.roads_out) > 1 and ((current_node.roads_out count ((road(each).embout_route = nil) or not road(each).embout_route.real) ) > 0){
					bool tj <- false;
					loop rd over: current_path.edges {
						if (road(rd).embout_route != nil and road(rd).embout_route.real and rd in roads_traffic_jam) {
							tj <- true;
							break;	
						}
					}
					if (tj) {
						do recomputing_path(general_speed_map_speed);
					}
				}
			}
		}
	}
	
	action driving {
		temps_passe <- temps_passe + 1;
		if (distance_to_goal = 0 and real_speed = 0) {
			proba_respect_priorities <- proba_respect_priorities - 0.1;
		} else {
			proba_respect_priorities <- 1.0;
		}
		do drive;
		if ((location distance_to target_node.location) < accepted_evacuation_distance){
			if (current_road != nil) {
				ask road(current_road) {
					do unregister(myself);
				}
			}
			do die;
		} 
	} 
	
	
	action compute_shortest_path (map<road,float> map_weights){
		map<road,float> rds <- [];
		loop rd over: roads_traffic_jam{
			float val <- map_weights[rd];
			rds[rd] <- val ;
			map_weights[rd] <-val * 10000;
		}
		road_network_custom <- road_network_custom  with_weights map_weights;
		current_path <- compute_path(graph: road_network_custom, target: target_node, source: current_node);
		nb_path_recompute <- nb_path_recompute + 1;
		loop rd over: roads_traffic_jam{
			map_weights[rd] <- rds[rd];
		}		
	}
	
	action recomputing_path (map<road,float> map_weights) {
		if (not mode_fuite and not mode_avoid and flip(proba_know_map)) {
			do compute_shortest_path(map_weights);
		}
		else if (not mode_fuite){
			if (not mode_avoid) {
				mode_avoid <- true;
				cpt_avoid <- 0;
			} 
			list<road> possible_edges <- list<road>(road_network_custom out_edges_of current_node);
			list<node_> possible_nodes <- [];
			loop rd over: possible_edges {
				if (rd.embout_route = nil or not rd.embout_route.real or (rd.target_node = target_node)  ) {
					possible_nodes << node_(rd.target_node);	
				}
			}
			if not empty(possible_nodes) {
				list<float> vals <- [];
				node_ the_temp_target <- nil;
				loop nd over:possible_nodes {
					float dist <- nd distance_to target_node;
					if dist = 0 {
						the_temp_target<- nd;
						break;
					}
					float angle <- float(abs(angle_between(nd.location, location, target_node.location)));
					if (angle > 180) {angle <- 360 - angle;}
					float val <- angle = 0 ? 1 : 1/angle;
						vals << val ;
				}
				if (the_temp_target = nil) {
					int index <- 0;
					if (sum(vals)> 0) {
						index <- rnd_choice(vals);
					}
					
					the_temp_target <- possible_nodes[index];
				}
				current_path <- path_from_nodes(graph: road_network_custom, nodes: [current_node, the_temp_target]);
			}
			
			
		}
		else if (mode_fuite) {
			list<road> possible_edges <- list<road>(road_network_custom out_edges_of current_node);
			list<node_> possible_nodes <- [];
			loop rd over: possible_edges {
				if (rd.target_node = current_node)   {
					possible_nodes << node_(rd.target_node);	
				}
			}
			if not empty(possible_nodes) {
				targets <- [];
				current_path <- nil;
			
				float angle_max <- 0.0;
				node_ the_temp_target <- nil;
				loop nd over:possible_nodes {
					float angle <- float(abs(angle_between(nd.location, location, first(point_fuite).location)));
					if (angle > 180) {angle <- 360 - angle;}
					if angle > angle_max {
						angle_max <- angle ;
						the_temp_target <- nd ;
					}
				}
				current_path <- path_from_nodes(graph: road_network_custom, nodes: [current_node, the_temp_target]);
			}
		}
	}
	
	aspect base { 
		draw triangle(20) color: color_behavior border: #black rotate:heading + 90;	
	} 
	
	aspect base_small { 
		draw triangle(1) color: color_behavior border: #black rotate:heading + 90;	
	} 
	
	aspect rang { 
		float val <- order * 3 /length(people) * 255;
		
		draw triangle(3) border: #black color: rgb(val, val, val) rotate:heading + 90;	
	} 
	
	float test_traffic_jam(road a_road, float rt) {
		if a_road.embout_route != nil and a_road.embout_route.real and (a_road in roads_traffic_jam) {
			current_path <- nil;
			return 0.0;
		} else {
			return rt;
		}
	}
	///////////////////////////////////////////////////////////////////////////////
	float external_factor_impact(road new_road,float remaining_time) {
		node_ current_node_tmp <- node_(new_road.source_node);
		//write name + " -> " + current_road +  " new_road:" + new_road ;			
		if (mode_avoid and not mode_fuite) {
				cpt_avoid <- cpt_avoid + 1;
				if (cpt_avoid > nb_avoid_max) {
					mode_avoid <- false;
					cpt_avoid <- 0;
				}
			}
	
		if ma_premiere_route {
			ma_premiere_route <- false ;
		} else {
			ask road(current_road) {
				nb_personnes <- nb_personnes + 1 ;
				nb_personnes_tot <- nb_personnes_tot + 1 ;
				temps_tot <- temps_tot + myself.temps_passe ;
				temps_tot_global <- temps_tot_global + myself.temps_passe;
			}
		}
		temps_passe <- 0 ;	
		if (mode_fuite ) {
			if (flip(0.9)) {
				recompute_path <- true;
				current_path <- nil;
				return remaining_time;
			} else {
				size <- 8;
				color_behavior <- #yellow;
				mode_fuite <- false;
			}
			
		}	

			
		if (proba_avoid_traffic_jam > 0 and flip(proba_avoid_traffic_jam)) {
			
			roads_traffic_jam <- remove_duplicates(roads_traffic_jam + (current_node_tmp.neighbours_tj)) where (not dead(each));// where (each.embout_route != nil and each.embout_route.real));// and not (each in roads_traffic_jam)));
			if (not empty(roads_traffic_jam) and  length(current_node_tmp.roads_out) > 1 and ((current_node_tmp.roads_out count ((road(each).embout_route = nil) or not road(each).embout_route.real) ) > 0)) {
				remaining_time <- test_traffic_jam(new_road, remaining_time);
				if (remaining_time > 0 and current_path != nil) {
					bool next <- false;
					loop rd over: current_path.edges {
						if (not next and current_node_tmp = road(rd).source_node) {
							next <- true;
						}
						if (next) {
							remaining_time <- test_traffic_jam(road(rd), remaining_time);
							if (current_path = nil) {
								recompute_path <- true;
								break;
							}
						}
					}
				}
			}
		}
		//write name + " -> recompute_path: " + recompute_path +  " current_path:" + current_path ;			
		if (current_path != nil) {
			new_road.nb_people_tot <- new_road.nb_people_tot + 1;
		}
		
		return remaining_time;
	}
	

	
} 

/*experiment sc_exceptionnel_optimized type: gui {
	parameter coeff_nb_people  var: coeff_nb_people among:[1.0] <- 1.0;
	output {
		monitor "nb people" value: length(people);
		monitor "nb path computation: " value: nb_path_recompute;
		
		display Graphiques refresh: every(10){
			chart "mean speed of people" type: series size:{0.5,0.5} position:{0.0,0.5} {
				data "mean speed of people" value: mean_real_speed color: #blue ;
			}
			
			chart "rapports" type: series size:{0.5,0.5} position:{0.5,3.5}{
				data "nb agents en mvt // nb agents" value: nb_driving_agent * 100 / (nb_agent_update) style: line color: #gray ;
				data "feux verts" value: (nb_traffic_signals_green * 100 / length(traffic_signals)) style: line color: #green ;
				data "routes embouteillees" value: (traffic_jam_nb_roads * 100 / length(road)) style: line color: #red ;
			}
			
			chart "infos use_traffic_lightsagents" type: series size:{0.5,0.5} position:{0.0,3.5}{
				data "nb  agents" value: length(people) style: line color: #black ; //nb_agent_update
				data "nb driving agent" value: nb_driving_agent style: line color: #red ;
				data "nb agents in t-jam" value: nb_agents_in_traffic_jam style: line color: #orange ;
				data "nb agent speed < 30 km/h" value: nb_agent_speed_30 color: #gray;
				data "nb agent speed == 0 km/h" value: nb_agent_speed_zero color: #purple;
			}
			chart "traffic jam length" type: series size:{0.5,0.5} position:{0.5,0.5}{
				data "traffic jam meters (cummulative)" value: traffic_jam_length color: #black;
			}
		}
	}
	
}*/


//experiment batch type: batch until: empty(people) {
experiment batch type: batch until: empty(people) or time > 5#h { // repeat: 3
	parameter "use_traffic_lights" var: use_traffic_lights among: [true, false];
	parameter "proba_fous:" var: proba_fous among: [0.0, 0.1, 0.5, 1.0];
	reflex fin_simu {
		write "use_traffic_lights:" + use_traffic_lights + "proba_fous:" + proba_fous +" time: " + time;
		save [use_traffic_lights, proba_fous, cycle] type:"csv" to: "use_traffic_lights_proba_fous_time.csv";
	}
	
}

experiment openmole type: gui  { // repeat: 3
	parameter "use_traffic_lights" var: use_traffic_lights;
	parameter "proba_fous" var: proba_fous;
	parameter "axes_majeurs" var: axes_majeurs;
    parameter "type_simulation" var: type_simulation;

	output {
		 display city_display refresh: every(2){ // retirer opengl
				species road aspect: pp refresh: false;
			 	species evacuation_urgence;
		 	
			species people aspect: base; 
		
		}  
	}	
	
}
experiment traffic_simulation_sc_exceptionnel type: gui {
	parameter axes_majeurs var: axes_majeurs;
	parameter nb_people_alea var: nb_people_alea;
	
	output {
		monitor "nb people" value: length(people);
		monitor "nb path computation: " value: nb_path_recompute;
	/* 	display carte_embouteillage{
			species road aspect: carto refresh: false;
			species embouteillage aspect: base_width ;
		} */
		
		 display city_display refresh: every(2){ // retirer opengl
		//	species danger aspect: base; 
			species road aspect: pp refresh: false;
		 //	species node_ aspect: base refresh: false; 
		 	species evacuation_urgence;
		 	
			species people aspect: base; 
			//species point_fuite; 

		}  
		
		
		
		display Graphiques refresh: every(60){
			chart "mean speed of people" type: series size:{0.5,0.5} position:{0.0,0.5} {
				data "mean speed of people" value: mean_real_speed color: #blue ;
			}
			
			chart "rapports" type: series size:{0.5,0.5} position:{0.5,3.5}{
				data "nb agents en mvt // nb agents" value: nb_driving_agent * 100 / (nb_agent_update) style: line color: #gray ;
				data "feux verts" value: (nb_traffic_signals_green * 100 / length(traffic_signals)) style: line color: #green ;
				data "routes embouteillees" value: (traffic_jam_nb_roads * 100 / length(road)) style: line color: #red ;
			}
			
			chart "infos agents" type: series size:{0.5,0.5} position:{0.0,3.5}{
				data "nb  agents" value: length(people) style: line color: #black ; //nb_agent_update
				data "nb driving agent" value: nb_driving_agent style: line color: #red ;
				data "nb agents in t-jam" value: nb_agents_in_traffic_jam style: line color: #orange ;
				data "nb agent speed < 30 km/h" value: nb_agent_speed_30 color: #gray;
				data "nb agent speed == 0 km/h" value: nb_agent_speed_zero color: #purple;
			}
			chart "traffic jam length" type: series size:{0.5,0.5} position:{0.5,0.5}{
				data "traffic jam meters (cummulative)" value: traffic_jam_length color: #black;
			}
		} 
	}
} 
 
