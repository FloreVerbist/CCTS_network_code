# D) OPTIONAL: Write scenario data
max_distance = 0.2                                                          # Cluster parameter  = max_distance x 111 km = ... km 
raw_file_gas =  eval(Symbol("raw_file_gas_", detail_level))                 # Scigrid input data (candidate pipelines - raw file)


## D.1) Industry data
for CO2 in CO2_tax_vect
    print(CO2)
    print("euro/tCO2 ETS price --- Scenario name: ")
    global CO2_tax = CO2
    for Scenario_name in Scenario_name_vect
        print(Scenario_name)
        print("     ")
        for Scenario_horizon in Scenario_horizon_vect
            AidRES_adj_model_perton = AidRES_scenario_adjustment(raw_file, scenario_file, Project_user_interface_file, Scenario_name, Scenario_horizon, CO2_tax)
            IndEmitters_df  = write_industrial_emitters_input_data(raw_file::Any, scenario_file::Any, industry_data_file::Any, Scenario_name::String, Scenario_horizon::Int64, (CRF = true; CRF), (cluster_save_data = false; cluster_save_data))
        end
    end

end

# To check the optimal routes
ROUTE_NAME = [1, 2, "noCC"] # 2
for route_name in ROUTE_NAME
    Routes_per_product = product_routes(results_product_file::String, raw_file::String,industry_data_file::String, Scenario_name_vect::Vector, Scenario_horizon_vect::Vector, route_name)

end

# Make sure that clusters are correct for each scenario --> if new centroid --> rerun this line: 
IndEmitters_df = write_industrial_emitters_input_data(raw_file::Any, scenario_file::Any, industry_data_file::Any, Scenario_name::String, Scenario_horizon::Int64,  (CRF = true; CRF), (cluster_save_data = false; cluster_save_data))

## D.2) T&S components coarse
Terminal_harbour_nodes_df = writing_terminal_input_data(raw_file_oil_terminals, raw_file_gas_terminals, EU_shape_file, system_data_file)
Routing_nodes_df = writing_routing_input_data(raw_file_gas, system_data_file)
Offshore_nodes_df = writing_offshore_nodes_input_data(raw_file_offshore_nodes, system_data_file)
Offshore_storages_df, Inland_storages_df = writing_storages_input_data(raw_file_storage, system_data_file)
Pipes_df = writing_pipeline_input_data(raw_file_gas, Centroids_df, Routing_nodes_df,Terminal_harbour_nodes_df, Offshore_nodes_df, Offshore_storages_df, Inland_storages_df, system_data_file) # less than halve of the lines!!!coarse <=> dense
preOpt_visualisation_py(shapefile_eu)