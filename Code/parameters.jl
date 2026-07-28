



# preprocessing (still)
EMITTERS = CCTS_element_selection(Region::String)


for i in 1:length(Pipelines[:,"Distance_km"])
    if Pipelines[i,"Distance_km"] .== 0.0
        Pipelines[i,"Distance_km"] = 1.0 # to make sure that there are no 0 length pipes --> otherwise some weird high solution pops up. 
    end
end
# visualisation parameters
# all routing nodes 
Routing_nodes_all_coordinates = [Routing_nodes_all[!, "Lat"] Routing_nodes_all[!, "Lon"]] 
Routing_nodes_all_name = string.(Routing_nodes_all[!, "Node_name"])
Routing_nodes_all_id = string.(Routing_nodes_all[!, "Node_id"])

# routing nodes of selected region    
# Routing_nodes = filter!(row -> !occursin(r"^T\d", row.Node_id), Routing_nodes) # delete terminal nodes to avoid overlap with terminal 
Routing_nodes_id = string.(Routing_nodes[!, "Node_id"])
Routing_nodes_coordinates = [Routing_nodes[!, "Lat"] Routing_nodes[!, "Lon"]] 

Offshore_nodes_id = string.(Offshore_nodes[!, "Node_id"])
Offshore_nodes_coordinates = [Offshore_nodes[!, "Lat"] Offshore_nodes[!, "Lon"]] 

Cluster_id = string.(unique(Clusters[:,"Cluster"]))
Cluster_coordinates = [Clusters[:,"Lat"] Clusters[:,"Lon"]] 
Cluster_coordinates_plot= DataFrame(Cluster_coordinates, [:Lat, :Lon])
# lat_cluster = Cluster_coordinates[:,1]
# lon_cluster = Cluster_coordinates[:,2]
# coordinate_matrix_cluster = hcat(lat_cluster, lon_cluster)
# gc = Geocoder()   
# NUTS0_cluster = [decode(gc, SA[lat_cluster[i], lon_cluster[i]])[2] for i in 1:length(lat_cluster)]
# Cluster_coordinates_plot[:, "NUTS0"] = NUTS0_cluster


#------------------------------------------------------------------------------
# sector specific 
Steel_emitters =  Emitters[Emitters[:, "Sector_name"] .== "Steel", :]
Steel_coordinates = [Steel_emitters[:, "Lat"] Steel_emitters[:, "Lon"]]
Steel_dict = Dict(Steel_emitters[i, "Emitter_id"] => (Steel_coordinates[i,2], Steel_coordinates[i,1])  for i in 1:length(Steel_emitters[:, "Emitter_id"])) 

Cement_emitters =  Emitters[Emitters[:, "Sector_name"] .== "Cement", :]
Cement_coordinates = [Cement_emitters[:, "Lat"] Cement_emitters[:, "Lon"]]
Cement_dict = Dict(Cement_emitters[i, "Emitter_id"] => (Cement_coordinates[i,2], Cement_coordinates[i,1])  for i in 1:length(Cement_emitters[:, "Emitter_id"])) 

Glass_emitters =  Emitters[Emitters[:, "Sector_name"] .== "Glass", :]
Glass_coordinates = [Glass_emitters[:, "Lat"] Glass_emitters[:, "Lon"]]
Glass_dict = Dict(Glass_emitters[i, "Emitter_id"] => (Glass_coordinates[i,2], Glass_coordinates[i,1])  for i in 1:length(Glass_emitters[:, "Emitter_id"])) 

Refineries_emitters =  Emitters[Emitters[:, "Sector_name"] .== "Refineries", :]
Refineries_coordinates = [Refineries_emitters[:, "Lat"] Refineries_emitters[:, "Lon"]]
Refineries_dict = Dict(Refineries_emitters[i, "Emitter_id"] => (Refineries_coordinates[i,2], Refineries_coordinates[i,1])  for i in 1:length(Refineries_emitters[:, "Emitter_id"])) 

Fertilisers_emitters =  Emitters[Emitters[:, "Sector_name"] .== "Fertilisers", :]
Fertilisers_coordinates = [Fertilisers_emitters[:, "Lat"] Fertilisers_emitters[:, "Lon"]]
Fertilisers_dict = Dict(Fertilisers_emitters[i, "Emitter_id"] => (Fertilisers_coordinates[i,2], Fertilisers_coordinates[i,1])  for i in 1:length(Fertilisers_emitters[:, "Emitter_id"])) 


Chemical_emitters =  Emitters[Emitters[:, "Sector_name"] .== "Chemical", :]
Chemical_coordinates = [Chemical_emitters[:, "Lat"] Chemical_emitters[:, "Lon"]]
Chemical_dict = Dict(Chemical_emitters[i, "Emitter_id"] => (Chemical_coordinates[i,2], Chemical_coordinates[i,1])  for i in 1:length(Chemical_emitters[:, "Emitter_id"])) 





#-------------------------------------------------------------------------------

Terminal_id = string.(Terminals[!, "Node_id"])
Terminal_coordinates = [Terminals[!, "Lat"] Terminals[!, "Lon"]] 

Storage_offshore_id = string.(Storage_offshore[!, "Node_id"])
Storage_offshore_coordinates = [Storage_offshore[!, "Lat"] Storage_offshore[!, "Lon"]] 

Storage_inland_id = string.(Storage_inland[!, "Node_id"])
Storage_inland_coordinates = [Storage_inland[!, "Lat"] Storage_inland[!, "Lon"]] 

Storages_id =  vcat(Storage_offshore_id, Storage_inland_id)
Storages_coordinates =  vcat(Storage_offshore_coordinates, Storage_inland_coordinates)

Pipe_id = [[string.(Pipelines[!, "Node_origin"][i]); string.(Pipelines[!, "Node_destination"][i])] for i in 1:1:length(Pipelines[:,1])]
Pipe_coordinates = [[Pipelines[!, "Longitude_origin"][i] Pipelines[!, "Latitude_origin"][i];  Pipelines[!, "Longitude_destination"][i] Pipelines[!, "Latitude_destination"][i] ] for i in 1:1:length(Pipelines[:,1])]

# Sline_names = [[string.(Shipping[!, "Node_name_origin"][i]); string.(Shipping[!, "Node_name_destination"][i])] for i in 1:1:length(Shipping[:,1])]
# Sline_coordinates = [[Shipping[!, "Longitude_origin"][i] Shipping[!, "Latitude_origin"][i];  Shipping[!, "Longitude_destination"][i] Shipping[!, "Latitude_destination"][i]] for i in 1:1:length(Shipping[:,1])]


SPipes_origin = Pipelines[startswith.(Pipelines.Node_origin, "Si") .| 
                                               startswith.(Pipelines.Node_origin, "So"), 
                                               "Node_origin"]

SPipes_destination = Pipelines[startswith.(Pipelines.Node_origin, "Si") .| 
startswith.(Pipelines.Node_origin, "So"), 
"Node_destination"]


Nodes_all = DataFrame(
    Node_id = vcat(vcat(vcat(vcat(vcat(Cluster_id,  Routing_nodes_all_id), Terminal_id), Offshore_nodes_id), Storage_offshore_id), Storage_inland_id), 
    Lat =   vcat(vcat(vcat(vcat(vcat(Cluster_coordinates[:,1],  Routing_nodes_all_coordinates[:,1]), Terminal_coordinates[:,1]), Offshore_nodes_coordinates[:,1]),Storage_offshore_coordinates[:,1]), Storage_inland_coordinates[:,1]),
    Lon =   vcat(vcat(vcat(vcat(vcat(Cluster_coordinates[:,2],  Routing_nodes_all_coordinates[:,2]), Terminal_coordinates[:,2]), Offshore_nodes_coordinates[:,2]),Storage_offshore_coordinates[:,2]), Storage_inland_coordinates[:,2])
)

Nodes = DataFrame(
    Node_id = vcat(vcat(vcat(vcat(vcat(Cluster_id,  Routing_nodes_id), Terminal_id), Offshore_nodes_id), Storage_offshore_id), Storage_inland_id), 
    Lat =   vcat(vcat(vcat(vcat(vcat(Cluster_coordinates[:,1],  Routing_nodes_coordinates[:,1]), Terminal_coordinates[:,1]), Offshore_nodes_coordinates[:,1]),Storage_offshore_coordinates[:,1]), Storage_inland_coordinates[:,1]),
    Lon =   vcat(vcat(vcat(vcat(vcat(Cluster_coordinates[:,2],  Routing_nodes_coordinates[:,2]), Terminal_coordinates[:,2]), Offshore_nodes_coordinates[:,2]),Storage_offshore_coordinates[:,2]), Storage_inland_coordinates[:,2])
)

Nodes_id = Nodes[:, "Node_id"]
Nodes_coordinates = [Nodes[!, "Lat"] Nodes[!, "Lon"]]


# Parameter sets


Emitter_cluster = Dict(emitter => string.(Emitters[Emitters[!,"Emitter_id"] .== emitter, "Cluster_julia"][1]) for emitter in EMITTERS) 
Cluster_emitters = Dict(cluster => Emitters[(string.(Emitters[!,"Cluster_julia"]) .== cluster), "Emitter_id"][:] for cluster in CLUSTERS) 
Cluster_abs_distance = cluster_refpoint_distance(system_data_file, CLUSTERS)
Tot_cluster_distance= sum(values(Cluster_abs_distance))
# Std_dev_cluster_distance = std(Clusters[:, "NZ_distance"])
Cluster_distance_rel_weight = Dict(cluster => Cluster_abs_distance[cluster]./Tot_cluster_distance for cluster in CLUSTERS) # Normalising the distance


Emitter_country = Dict(emitter => string.(Emitters[Emitters[!,"Emitter_id"] .== emitter, "NUTS0"][1]) for emitter in EMITTERS) 
COUNTRIES = unique(vcat(values(Emitter_country)...))


TIMES = 1:1:1 
NODES = vcat(vcat(vcat(vcat(vcat(Cluster_id,  Routing_nodes_id), Terminal_id), Offshore_nodes_id), Storage_offshore_id), Storage_inland_id)
PIPES = [(Pipelines[i, "Node_origin"], Pipelines[i,"Node_destination"]) for i in 1:1:length(Pipelines[!,1])]
SPIPES = [(SPipes_origin[i], SPipes_destination[i]) for i in 1:1:length(SPipes_origin)]
# SLINES = [(Shipping[i, "Origin"], Shipping[i,"Destination"]) for i in 1:1:length(Shipping[!,1])]

ROUTING =   Routing_nodes_id
# STORAGES_OFF = Storage_offshore_id
# STORAGES_OFF = Storage_offshore[Storage_offshore[:,"NUTS0"] .!= "GB", "Node_id"] # no UK storage

if UK_storage == false
    print("No GB storage")
    STORAGES_OFF = Storage_offshore[Storage_offshore[:,"NUTS0"] .!= "GB", "Node_id"] # no UK storage
    # STORAGES_OFF = Storage_offshore[:, "Node_id"] # UK storage - senstivity
else 
    print("GB storage")
    STORAGES_OFF = Storage_offshore[:, "Node_id"] # UK storage allowed
    print(STORAGES_OFF)
end
STORAGES_INL = Storage_inland_id
# STORAGES_INL = []


STORAGES_INL = Storage_inland_id
# STORAGES_INL = []




# Parameters 
####################################################################################################
##  T & S CHARACTERISTICS
####################################################################################################

# Storage_inl_capacity =  Dict(storage_node => 50.0  for storage_node in Storage_inland_id) #Mtpa
# Storage_off_capacity =  Dict(storage_node => 50.0 for storage_node in Storage_offshore_id) #Mtpa

Storage_periods = 20
# Storage_inl_capacity =  Dict(storage_node => minimum([50.0, Storage_inland[Storage_inland[:,"Node_id"] .== storage_node, "Theoretical_volume_mtpa"][1]]) for storage_node in Storage_inland_id) #Mtpa
# Storage_off_capacity =  Dict(storage_node => minimum([50.0,Storage_offshore[Storage_offshore[:,"Node_id"] .== storage_node, "Theoretical_volume_mtpa"][1]]) for storage_node in Storage_offshore_id) #Mtpa
Storage_inl_capacity =  Dict(storage_node => Storage_inland[Storage_inland[:,"Node_id"] .== storage_node, "Theoretical_volume_mt"][1]./Storage_periods for storage_node in Storage_inland_id) #Mtpa
Storage_off_capacity =  Dict(storage_node => Storage_offshore[Storage_offshore[:,"Node_id"] .== storage_node, "Theoretical_volume_mt"][1]./Storage_periods for storage_node in Storage_offshore_id) #Mtpa




# Maximizing the Dutch capacities on 20 Mtpa or italian volumes to 0

# [Storage_off_capacity[NodeID] = minimum([Storage_offshore[Storage_offshore[:,"Node_id"].==  NodeID, "Theoretical_volume_mtpa"][1], 100.0]) for NodeID in Storage_offshore[:, "Node_id"]] #Mtpa
# [Storage_off_capacity[NodeID] = minimum([Storage_offshore[Storage_offshore[:,"Node_id"].==  NodeID, "Theoretical_volume_mtpa"][1], 0.0]) for NodeID in Storage_offshore[Storage_offshore[:,"NUTS0"].== "IT", "Node_id"]] #Mtpa

Index_costs = Costs[!, "Parameter"]
Index_pipe = Pipelines[!, "Pipeline_id"]
# Pipe_name = Dict(Pipelines[!, "Pipeline_id"][p] => PIPES[p] for p in 1:1:length(PIPES) )
Pipe_name = Dict(row["Pipeline_id"] => (row["Node_origin"], row["Node_destination"]) for row in eachrow(Pipelines)) # robuster than line above
Pipe_distance = Dict(value => Pipelines[Index_pipe .== key, "Distance_km"][1] for (key, value) in Pipe_name)
# Sline_distance = Dict(value => Shipping[Index_sline .== key, "Distance_km"][1] for (key, value) in Sline_name)
####################################################################################################
##  COST
####################################################################################################
interest = 0.08
#################### PIPELINE PART ####################
# S Mccoy and E Rubin. “An engineering-economic model of pipeline transport of  CO2 with application to carbon capture and storage”. In: International Journal
# of Greenhouse Gas Control 2.2 (Apr. 2008), pp. 219–229. issn: 17505836. doi:10.1016/S1750-5836(07)00119-3. 
# url: https://linkinghub.elsevier.com/retrieve/pii/S1750583607001193 (visited on 03/11/2024).

Meter_per_inch = 0.0254
Inch_per_meter = 1/0.0254
Density_2 = 800 #kg/m3
Velocity = 2.0 #m/s
Pipe_periods = 50 #20  # Danish Energy Agency: file:///C:/Users/VERBISTF/Downloads/technology_data_for_carbon_capture_transport_and_storage_0.pdf
reference_year = 2024 
Plotting = false

OandM_pipes = 0.05
A0_pipe_construct, A2_pipe_construct = CMU_pipe_construction(Pipe_periods, interest, reference_year, Plotting::Bool)
f_transport(q) = (1+OandM_pipes).*sum(A0_pipe_construct.*(((q.* 10^9 ./ (365*24*60*60))./(Velocity*pi*0.25*Density_2)).^0.5*Inch_per_meter).^(A2_pipe_construct)) #MEUR
PIECES = 1:Pieces
Regression_transport =  piecewise_error(Range_opt, Pieces, Samples, Intercept)
# println("Transport Regression parameters:", Regression_transport)
A_0_pc_transport = Regression_transport[!,"A_0"][1]
A_1_pc_transport = Regression_transport[!,"A_1"][1]
Mpipe_pc_transport = Regression_transport[!,"x_breakpoints"][1]

#################### BOOSTER PUMP PART ####################
# IEA GHG. Building the Cost Curves for CO2 Storage: European Sector. Technical Report 2005/2, International Energy Agency, 2005. URL
# https://ieaghg.org/publications/building-the-cost-curves-for-co2-storage-european-sector/.
Pressure_diff = 4*10^6 # Pa 
BP_periods = 20
BP_distance = 200 #km
BP_eff = 0.75
BP_inv = cost_converter(10, BP_periods, interest, 2002, reference_year, false)/BP_distance #_MEURpapkm 
BP_elec_cons = ((1/Density_2)*Pressure_diff/BP_eff)/BP_distance # J/kg/km 
energy_commodity_prices = DataFrame(XLSX.readtable(Project_user_interface_file, "energy_commodity_prices"; first_row = 5, header= false, column_labels = ["Commodity", "Preset", "2030", "2050", "Unit"]))
P_elec = energy_commodity_prices[energy_commodity_prices[:, "Commodity"] .== "Electricity", string(Scenario_horizon)][1]  #EUR/kWh 
OandM_BP = 0.05 
f_BP(q) = ((1+ OandM_BP) *BP_inv +  BP_elec_cons * P_elec /(3.6*10^3) * q ) # #MEUR/km --> vermenigvuldigen met lengte 

#################### STORAGE PART ####################
# IEA GHG. Building the Cost Curves for CO2 Storage: European Sector. Technical Report 2005/2, International Energy Agency, 2005. URL
# https://ieaghg.org/publications/building-the-cost-curves-for-co2-storage-european-sector/.
# Storage_periods = 20
Reservoir_inv = cost_converter(1.8, Storage_periods, interest, 2004, reference_year, false) #_MEURpapkm 
Drilling_inv_per_meter = cost_converter(2500/10^6, Storage_periods, interest, 2004, reference_year, false)   # MEUR/m
Reservoir_depth = 2000 #msens
Horizontal_distance = 1000 # m
Reservoir_thickness = 125 #m
Platform_inv = cost_converter(50, Storage_periods, interest, 2004, reference_year, false) #MEURpa
Monitoring_inv = cost_converter(2, Storage_periods, interest, 2004, reference_year, false) # MEURpa
Monitoring_opex = cost_converter(0.03, "none", "none", 2004, reference_year, false) #EUR/tCO2
OandM_storage = 0.07 

C_reservoir_inv = Reservoir_inv # A^(R,INV): MEUR per facility - site development costs 
C_drilling_inv =  Drilling_inv_per_meter*(Reservoir_thickness + Reservoir_depth + 2*Drilling_inv_per_meter*Horizontal_distance) # AD, INV(LRD + LRT + 2HR) MEUR per facility # aconsidering this is only for one well and each Well can only store 1 MtCO2/yr --> MEUR/MtCO2pa  (p111)
C_surface_facility_inv = Platform_inv/6 # A^(SP,INV): MEUR per facility - surface facility cost per platform (6 wells per platform)
C_monitoring_inl = Monitoring_inv # A^(M,INV,INL): MEUR per onshore facility
C_monitoring_off_per_ton = Monitoring_opex # A^(M,INV,OFF): MEUR/Mton per offshore injection
f_storage(x) = (1+OandM_storage)*(C_reservoir_inv + C_drilling_inv + C_surface_facility_inv + C_monitoring_inl) #MEUR for only one well drilling investment 

#################### OLD PIPELINE PART ####################

# Index_sline = Shipping[!, "Line"]
Mpipe = 10^3 # this is actually what you think would be the maximum allowed capacity --> Q_max for a pipeline. 
Memitter = 10^4 # 10^5
Lifetime_pipe = 100



# Sline_name = Dict(Shipping[!, "Line"][p] => SLINES[p] for p in 1:1:length(SLINES) )

Cost_storage = Costs[Index_costs .=="Cost_storage", "Value"]
# A = a0 as used by  Joris Morbee, Joana Serpa, and Evangelos Tzimas. “Optimised deployment of
#a European CO2 transport network”. In: International Journal of Greenhouse
#Gas Control 7 (Mar. 2012), pp. 48–61. issn: 17505836. doi: 10.1016/j.ijggc.
#2011.11.011. url: https://linkinghub.elsevier.com/retrieve/pii/
# S1750583611002210 (visited on 12/18/2023).
# & chemical plant cost index = cost time B = cost time A x (index time B/index time A ) https://toweringskills.com/financial-analysis/cost-indices/
A_inv_pipe = 0.533 * 295.5/183.5  #Costs[Index_costs .=="A_inv_trans", "Value"]
B_inv_pipe =  0.019 *  295.5/183.5  #Costs[Index_costs .=="B_inv_trans", "Value"]
# A0_OaM_pipe = - 0.466624 *  295.5/120.9 * 0.95   # MEur 
# A1_OaM_pipe = 2.461339 *  295.5/120.9 * 0.95   # MEur/km
# A2_OaM_pipe =  
Terrain = Costs[Index_costs .=="Terrain", "Value"]
OandM_pipe = Costs[Index_costs .=="OandM_trans", "Value"]
Alpha_ship = Costs[Index_costs .=="Alpha_ship", "Value"]
Beta_ship = Costs[Index_costs .=="Beta_ship", "Value"]
Gamma_ship = Costs[Index_costs .=="Gamma_ship", "Value"]
Delta_ship = Costs[Index_costs .=="Delta_ship", "Value"]
Lifetime =  Costs[Index_costs .=="Lifetime_other", "Value"]


TOT_production = Dict(emitter => Emitters[Emitters[!,"Emitter_id"] .== emitter, "Product_cap_ktpa"][1]./1000 for emitter in EMITTERS) # Mtpa

TOT_bio_CO2 = Dict(emitter => Emitters[Emitters[!,"Emitter_id"] .== emitter, "Capture_ofwhich_bio_1_tCO2ptpa"][1].* TOT_production[emitter] for emitter in EMITTERS) # Mtpa
TOT_fossil_CO2 = Dict(emitter => (Emitters[Emitters[!,"Emitter_id"] .== emitter, "Captured_CO2_1_tCO2ptpa"][1] .- Emitters[Emitters[!,"Emitter_id"] .== emitter, "Capture_ofwhich_bio_1_tCO2ptpa"][1] ).* TOT_production[emitter] for emitter in EMITTERS) #Mtpa # 

TOT_capture_1_CO2 = Dict(emitter => (Emitters[Emitters[!,"Emitter_id"] .== emitter, "Captured_CO2_1_tCO2ptpa"][1]).* TOT_production[emitter] for emitter in EMITTERS) #Mtpa # captured of cheapest (TOTEX based) solution (can be also zero) 

TOT_CO2_BASE_TOT = Dict(emitter => Emitters[Emitters[!,"Emitter_id"] .== emitter, "Base_emissions_tot_tCO2ptpa"][1].*TOT_production[emitter] for emitter in EMITTERS) #Mtpa - base emissions of conventional production process
TOT_CO2_BASE_DIRECT = Dict(emitter => Emitters[Emitters[!,"Emitter_id"] .== emitter, "Base_emissions_direct_tCO2ptpa"][1].*TOT_production[emitter] for emitter in EMITTERS) #Mtpa - base emissions of conventional production process
TOT_CO2_1 = Dict(emitter => Emitters[Emitters[!,"Emitter_id"] .== emitter, "direct_emission_1_tco2_t"][1].*TOT_production[emitter] for emitter in EMITTERS) #Mtpa - resulting emissions of the decarbonisation route. 
TOT_CO2_noCC = Dict(emitter => Emitters[Emitters[!,"Emitter_id"] .== emitter, "direct_emission_noCC_tco2_t"][1].*TOT_production[emitter] for emitter in EMITTERS) #Mtpa - resulting emissions of the decarbonisation route. 

# Capture_eff = Dict(emitter => Emitters[Emitters[!,"Emitter"] .== emitter, "Capture_eff"][1] for emitter in EMITTERS)
CAPEX_1 = Dict(emitter => Emitters[Emitters[!,"Emitter_id"] .== emitter, "Capex_1_EURptpa"][1].*TOT_production[emitter] for emitter in EMITTERS)    # MEur - capex of cheapest (TOTEX based) solution (can be carbon capture or not)
OPEX_1 = Dict(emitter => Emitters[Emitters[!,"Emitter_id"] .== emitter, "Opex_noTandS_1_EURptpa"][1].*TOT_production[emitter] for emitter in EMITTERS)  # MEur - non T&S opex of cheapest (TOTEX based) solution (can be carbon capture or not)

CAPEX_noCC = Dict(emitter => Emitters[Emitters[!,"Emitter_id"] .== emitter, "Capex_noCC_EURptpa"][1].*TOT_production[emitter] for emitter in EMITTERS)          # MEur - capex of  cheapest (TOTEX based) solution which is not CC
OPEX_noCC = Dict(emitter => Emitters[Emitters[!,"Emitter_id"] .== emitter, "Opex_noTandS_noCC_EURptpa"][1].*TOT_production[emitter] for emitter in EMITTERS)    # MEur - non T&S opex of cheapest (TOTEX based) solution which is not CC

############################## carbon price
other_variables = DataFrame(XLSX.readtable(Project_user_interface_file, "other_variables"; first_row = 6, header = false, column_labels = ["Method", "Sector", "Product", "2030", "2050", "Description"]))
ETS_price = other_variables[coalesce.(other_variables[:, "Method"], "") .== "Carbon Cost", string(Scenario_horizon)][1]


