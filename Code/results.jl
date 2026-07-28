function variable_to_dict(x)

    # Extract the keys and values from the variable outcomes
    keys_x = keys(x)  # Get the keys (indices) of the variable x
    values_x = value.(x)  # Get the values (outcome) of the variable x
    
    # Create a dictionary where the keys are indices and values are the variable outcomes
    x_dict = Dict(k => values_x[k] for k in keys_x)
    global max_value = 0 
    global max_key = 0
    for (k, v) in x_dict
        if v > max_value
            max_value = v
            max_key = k
        end
    end
    non_zero_dict = Dict(filter(x -> x[2] != 0, x_dict))
    
    return non_zero_dict
end 

function variables_extract(model::Model)
    for key in keys(model.ext[:variables])
        if key .== :cc_emitter
            V = round.(value.(model.ext[:variables][key]), digits = 2)
        else 
            V = value.(model.ext[:variables][key])
        end
        @eval $key = $V
    end
    return
end

function parameters_extract(model::Model)
    for key in keys(model.ext[:parameters])
        P = model.ext[:parameters][key]
        @eval $key = $P
    end
end


function mass_flow_to_diameter(Pipes_opt_sizes)
    # input should be mass flow in Mt/yr
    # gives the cm output of diameter belonging to mass flow
    D_opt_pipe = (((Pipes_opt_sizes).*(4/pi)).^2 .* (0.015 ./(2*850*0.3))).^(2/5).*100  #in cm q * (4/pi)^2 * f/ (2 * rho * delta_p/L) ] ^(2/5)
    D_opt_pipe = ((Pipes_opt_sizes).*(4/(pi*850*0.3))).^(1/2) .*100  
    # check: [1] H. Lu, X. Ma, K. Huang, L. Fu, and M. Azimi, “Carbon dioxide transport via pipelines: A systematic review,” Journal of Cleaner Production, vol. 266, p. 121994, Sep. 2020, doi: 10.1016/j.jclepro.2020.121994.

    Q_m = Pipes_opt_sizes .* 10^9 ./ (365*24*60*60) #kg/s 
    Density = 890.1551 # kg/m3  # calculator based on 15°C and 10 Mpa (100 bar) https://www.egichem.com/tools/calculators/carbon-dioxide/
    Viscosity = 9.0422E-05 # Pa.s 
    
    Q_v = Q_m ./ Density # m3/s 
    # Formula of: ([1] Z. X. Zhang, G. X. Wang, P. Massarotto, and V. Rudolph, “Optimization of pipeline transport for CO2 sequestration,” Energy Conversion and Management, vol. 47, no. 6, pp. 702–715, Apr. 2006, doi: 10.1016/j.enconman.2005.06.001.)    
    D_opt_pipe = 0.363.*Q_v.^(0.45).*Density.^(0.13)*Viscosity.^(0.025) # m 

    # IEA GHG. Building the Cost Curves for CO2 Storage: European Sector. Technical Report 2005/2, International Energy Agency, 2005. URL
    # https://ieaghg.org/publications/building-the-cost-curves-for-co2-storage-european-sector/.
    Meter_per_inch = 0.0254
    Inch_per_meter = 1/0.0254
    Density_2 = 800 #kg/s
    Velocity = 2.0 #m/s
    D_opt_pipe_2 = (Q_m./(Velocity*pi*0.25*Density_2)).^0.5 # m --> output slightly closer to Middelton, 2012

    return  D_opt_pipe_2 # m
end


function key_results_save(model_1, detail_level, results_stats_file, results_industry_file, scenario_file)
    result_file_intermediate = results_industry_file
    variables_extract(model_1)
    Values_cc_emitter = cc_emitter
    Max_total_connections = count(!iszero,values(TOT_capture_1_CO2))
    Total_connections  = count(!iszero,Values_cc_emitter[e].*TOT_capture_1_CO2[e] for e in EMITTERS)
    Total_fossil_capture = round(sum(Values_cc_emitter[e].*TOT_fossil_CO2[e] for e in EMITTERS), digits=2)
    Total_bio_capture = round(sum(Values_cc_emitter[e].*TOT_bio_CO2[e] for e in EMITTERS), digits=2)

    Total_bio_scenario_twh = biomass_quantities(Scenario_name, Scenario_horizon, result_file_intermediate, scenario_file)

    All_values_cc_emitters = [v for (k, v) in zip(keys(Values_cc_emitter), Values_cc_emitter) if v >= 0.000]
    V_cc_emitter = [v for (k, v) in zip(keys(Values_cc_emitter), Values_cc_emitter) if v >= 0.001]
    K_cc_emitter = [k[1] for (k, v) in zip(keys(Values_cc_emitter), Values_cc_emitter) if v >= 0.001]
    TOT_capture_cc_emitters = round(sum(Values_cc_emitter[i].*(TOT_bio_CO2[i] .+ TOT_fossil_CO2[i]) for i in EMITTERS), digits=2)
    Total_capture_potential = sum(values(TOT_capture_1_CO2))
    t_average =  round(c_operator/TOT_capture_cc_emitters, digits=2)

    obj_value = c_operator .+ sum(cc_emitter[n].*(CAPEX_1[n] .+ OPEX_1[n]) + (1-cc_emitter[n]).*(CAPEX_noCC[n] .+ OPEX_noCC[n]) for n in EMITTERS)
    Total_costs = 0 # obj_value / sum(TOT_CO2_BASE_DIRECT[e] - cc_emitter[e]*(TOT_CO2_1[e]) - (1-cc_emitter[e])*TOT_CO2_noCC[e] for e in EMITTERS) # cost per reduced (direct) CO2 emission 
    GAP = gap*100
    Key_output = [Max_total_connections, Total_connections, Total_capture_potential, TOT_capture_cc_emitters, Total_fossil_capture, Total_bio_capture, Total_bio_scenario_twh, t_average, Total_costs, 
    c_transport, c_storage, c_booster_pump, GAP, detail_level]
    Key_output_df = DataFrame()
    Key_output_df.Parameters = ["Max total connections", "Optimised connections", "Total capture potential",  "Total capture volume", "Total capture volume fossil", "Total capture volume bio", "Biomass use", "Average T&S costs", "Total costs", "Pipeline cost", "Storage cost", "Booster cost", "MIPgap", "C-grid-type"]
    Key_output_df.Values =    Key_output 
    Key_output_df.Unit = ["-", "-", "MtCO2pa", "MtCO2pa", "MtCO2pa", "MtCO2pa", "TWhpa", "EUR/tCO2pa", "EUR/tCO2Reducedpa", "MEURpa","MEURpa", "MEURpa", "%", "-"]


    if MPEC .== true
        filename_stats = "./Output data files/CSV intermediaries $(detail_level)/MPEC/Results_statistics_$(Scenario_name)_$(CO2_tax)_$(Subcase_name).csv"
    else 
        filename_stats = "./Output data files/CSV intermediaries $(detail_level)/Results_statistics_$(Scenario_name)_$(CO2_tax)_$(Subcase_name).csv"
    end

    CSV.write(filename_stats, Key_output_df)
  
        # XLSX.openxlsx(results_stats_file, mode="rw") do xf
        #     SheetName = "$(Scenario_name)_$(Region)_$(CO2_tax)"
        #         try 
        #             XLSX.addsheet!(xf, SheetName)
        #         catch 
        #         end
        #         try 
        #             sheet = xf[SheetName]
        #             XLSX.writetable!(sheet,Key_output_df; anchor_cell=XLSX.CellRef("A1")) # NOTE: if shorter df --> some rows of previous run might still be included in excel table. (not yet resolved nicely: https://felipenoris.github.io/XLSX.jl/stable/api/)
        #         catch e 
        #             print("Error writing table: $e")
        #         end
        # end

    print(Key_output_df)
     return Key_output_df
end 



# Usage



function industrial_results_save(model_1, results_industry_file::String)
    variables_extract(model_1)
    Values_cc_emitter = cc_emitter
    Industry_df_participation = DataFrame(
        Emitters = axes(Values_cc_emitter,1),
        Bin_connection = values(Values_cc_emitter).data
    )
    # Max_total_connections = count(!iszero,values(TOT_capture_1_CO2))
    if MPEC .== true
        filename_industry = "./Output data files/CSV intermediaries $(detail_level)/MPEC/Results_industry_$(Scenario_name)_$(CO2_tax)_$(Subcase_name).csv"
    else
        filename_industry = "./Output data files/CSV intermediaries $(detail_level)/Results_industry_$(Scenario_name)_$(CO2_tax)_$(Subcase_name).csv"
    end
    CSV.write(filename_industry, Industry_df_participation)



        # XLSX.openxlsx(results_industry_file, mode="rw") do xf
        #     SheetName = "$(Scenario_name)_$(Region)_$(CO2_tax)"
        #     try 
        #         XLSX.addsheet!(xf, SheetName)
        #     catch 
        #     end
        #     sheet = xf[SheetName]
        #     XLSX.writetable!(sheet,Industry_df_participation; anchor_cell=XLSX.CellRef("A1")) # NOTE: if shorter df --> some rows of previous run might still be included in excel table. (not yet resolved nicely: https://felipenoris.github.io/XLSX.jl/stable/api/)
        # end

     
end 

# function industrial_results_save(results_industry_file::String)

#     #         new_data = Industry_results_df
#     #         # Read the data into a DataFrame
#     #         df = DataFrame(XLSX.readtable(results_industry_file, "Sheet1"))
    
#     # # Check if the row with the same Scenario_name and Scenario_horizon exists
#     # existing_row = findfirst(row -> row.Scenario_name == Scenario_name &&
#     #                                     row.Scenario_horizon == Scenario_horizon, eachrow(df))
    
#     # if isnothing(existing_row)
#     #     # If the row doesn't exist, append a new row
#     #     df = vcat(df,new_data)
#     # else
#     #     # If the row exists, update it
#     #     for CN in names(new_data)
#     #         df[existing_row, CN] .== new_data[:,CN][1]
#     #     end
#     # end
#     # XLSX.openxlsx(results_industry_file, mode="rw") do xf
#     #     global df_print = df
#     #     # Write the updated DataFrame back to the Excel sheet
#     #     sheet = xf["Sheet1"]
#     #     XLSX.writetable!(sheet,df_print; anchor_cell=XLSX.CellRef("A1"))
#     # end
    


#     return
# end

function biomass_quantities(Scenario_name::String, Scenario_horizon::Int64, results_industry_file::String, scenario_file::String)
    Emitters = import_data_industry(CO2_tax::Any, Scenario_name::String, Scenario_horizon::Int64)
    EMITTERS = CCTS_element_selection(Region)

    if MPEC .== true 
        file_industry = "./Output data files/CSV intermediaries $(detail_level)/MPEC/Results_industry_$(Scenario_name)_$(CO2_tax)_$(Subcase_name).csv"
    else
        file_industry = "./Output data files/CSV intermediaries $(detail_level)/Results_industry_$(Scenario_name)_$(CO2_tax)_$(Subcase_name).csv"
    end

    Industry_connection_results = CSV.read(file_industry, DataFrame)
    file_preprocessing = "./Input data files/CSV inputs/$(CO2_tax)/Scenario_$(Scenario_name)_$(Scenario_horizon)_perton.csv"
    Scenario_model_perton = CSV.read(file_preprocessing, DataFrame)

   
    cc_emitter_tot =  Dict(e => try Industry_connection_results[Industry_connection_results[:, "Emitters"] .== e, "Bin_connection"][1] catch skip end for e in EMITTERS)
    
    
    Emitter_ref = Emitters[Emitters[:, "Sector_name"] .== "Refineries", "Emitter_id"]
    EMITTERS_REF = intersect(Emitter_ref, EMITTERS)
    Total_bio_scenario_gj = 0
    Total_bio_scenario_t = 0 
    for E_id in EMITTERS
    
            Config_id_1  = Emitters[Emitters[:, "Emitter_id"] .== E_id, "Config_id_1"][1]
            Config_id_noCC = Emitters[Emitters[:, "Emitter_id"] .== E_id, "Config_id_noCC"][1] 
            cc_id = cc_emitter_tot[E_id] 
            Prod_volume  = Emitters[Emitters[:, "Emitter_id"] .== E_id, "Product_cap_ktpa"][1].*1000 #tpa
            Bio_1_gj_t = Scenario_model_perton[Scenario_model_perton[:, "configuration_id"] .== Config_id_1, "biomass_[gj/t]"][1] + Scenario_model_perton[Scenario_model_perton[:, "configuration_id"] .== Config_id_1, "biomass_waste_[gj/t]"][1] 
            Bio_noCC_gj_t =  Scenario_model_perton[Scenario_model_perton[:, "configuration_id"] .== Config_id_noCC, "biomass_[gj/t]"][1] + Scenario_model_perton[Scenario_model_perton[:, "configuration_id"] .== Config_id_noCC, "biomass_waste_[gj/t]"][1] 
            Bio_1_t_t = Scenario_model_perton[Scenario_model_perton[:, "configuration_id"] .== Config_id_1, "biomass_[t/t]"][1] + Scenario_model_perton[Scenario_model_perton[:, "configuration_id"] .== Config_id_1, "biomass_waste_[t/t]"][1] 
            Bio_noCC_t_t =  Scenario_model_perton[Scenario_model_perton[:, "configuration_id"] .== Config_id_noCC, "biomass_[t/t]"][1] + Scenario_model_perton[Scenario_model_perton[:, "configuration_id"] .== Config_id_noCC, "biomass_waste_[t/t]"][1] 
            
            
            Total_bio_scenario_gj += (cc_id*Bio_1_gj_t + (1- cc_id)*Bio_noCC_gj_t)*Prod_volume
            Total_bio_scenario_t += (cc_id*Bio_1_t_t + (1- cc_id)*Bio_noCC_t_t)*Prod_volume
   
    
    end 
    Total_bio_scenario_twh = Total_bio_scenario_gj./ (3600*10^3) # = J--> kWh  = GJ --> TWh 
    Total_bio_scenario_Mt = Total_bio_scenario_t./ (10^6) # = t --> Mt

return Total_bio_scenario_twh
end

function product_routes(results_product_file::String, raw_file::String,industry_data_file::String, Scenario_name_vect::Vector, Scenario_horizon_vect::Vector, Route_name)

    AidRES_industrial_parameters = DataFrame(XLSX.readtable(raw_file, "AIDRES industrial_parameters"))
    AidRES_production_route_types = DataFrame(XLSX.readtable(raw_file, "AIDRES production_route_types"))
    AidRES_product_types = DataFrame(XLSX.readtable(raw_file, "AIDRES product_types"))
    PRODUCT_ID = [try AidRES_industrial_parameters[AidRES_industrial_parameters[!,"id"] .== i, "production_route_id" ][1] catch missing end for i in AidRES_industrial_parameters[!,"id"]] # works
    PRODUCT_NAMES1 = [try AidRES_production_route_types[AidRES_production_route_types[!, "id"] .== k, "wp1_model_product_name"][1] catch  missing end for k in PRODUCT_ID]
    PRODUCT_NAMES2 = [if value .== "at level of product_type" AidRES_product_types[AidRES_product_types[:,"id"] .== AidRES_industrial_parameters[nr, "product_type_id"], "wp1_model_produc_name"][1] else value  end for (nr, value) in enumerate(PRODUCT_NAMES1)]
    unique_product_names = unique(PRODUCT_NAMES2)[2:end]
    Scenarios = vec(["$(scenario)_$(horizon)" for scenario in Scenario_name_vect, horizon in Scenario_horizon_vect])
    Column_names = vcat(["Product_names"], Scenarios)
    df_opt_route = DataFrame([Symbol(C) => Vector{Any}(undef, length(unique_product_names))  for C in Column_names]...)
    df_opt_route[:, "Product_names"] = unique_product_names;
    for Scenario_name in Scenario_name_vect
        for Scenario_horizon in Scenario_horizon_vect
            # df_scenario = DataFrame(XLSX.readtable(industry_data_file, "Industry_$(Scenario_name)_$(Scenario_horizon)"))
            industry_data_file_csv = "./Input data files/CSV inputs/$(CO2_tax)/industry_system_data_$(Scenario_name).csv"
            df_scenario = CSV.read(industry_data_file_csv, DataFrame)
            scenario_select_vect = [try df_scenario[df_scenario[:,"Product_route_name"] .== i, "Route_name_$(Route_name)"][1] catch missing end for i in unique_product_names] # prints the first one of all sites (should be the same for all sites anyway)
            config_select_vect = [try df_scenario[df_scenario[:,"Product_route_name"] .== i, "Config_id_$(Route_name)"][1] catch missing end for i in unique_product_names]
            df_opt_route[:, "$(Scenario_name)_$(Scenario_horizon)"] = ["$(scenario_select_vect[i])   -$(config_select_vect[i])" for i in 1:length(scenario_select_vect)]
            Wtp_EURptCO2pa = [try (df_scenario[df_scenario[:,"Product_route_name"] .== i, "Totex_noCC_EURptpa"][1]-df_scenario[df_scenario[:,"Product_route_name"] .== i, "Totex_1_EURptpa"][1])/(df_scenario[df_scenario[:,"Product_route_name"] .== i, "Captured_CO2_1_tCO2ptpa"][1]) catch missing end for i in unique_product_names]
            df_opt_route[:, "WtP_$(Scenario_name)_EUR/tCO2"] = Wtp_EURptCO2pa


        end
    end

    XLSX.openxlsx(results_product_file, mode="rw") do xf
        SheetName = "Scenario_routes_$(Route_name)"
        try 
            XLSX.addsheet!(xf, SheetName)
        catch 
        end
        sheet = xf[SheetName]
        XLSX.writetable!(sheet,df_opt_route; anchor_cell=XLSX.CellRef("A1")) # NOTE: if shorter df --> some rows of previous run might still be included in excel table. (not yet resolved nicely: https://felipenoris.github.io/XLSX.jl/stable/api/)
    end
return df_opt_route
end


function pipeline_results_save(results_pipes_file::String, Pipes_opt_co_na, Pipes_opt_sizes)
    lon_1  = [values.(Pipes_opt_co_na)[i][1] for i in 1:length(Pipes_opt_co_na)]
    lat_1  = [values.(Pipes_opt_co_na)[i][3] for i in 1:length(Pipes_opt_co_na)]
    lon_2  = [values.(Pipes_opt_co_na)[i][2] for i in 1:length(Pipes_opt_co_na)]
    lat_2  = [values.(Pipes_opt_co_na)[i][4] for i in 1:length(Pipes_opt_co_na)]
    # Pipes_df_results = DataFrame("Pipeline_coordinates" => string.(values.(Pipes_opt_co_na)), "Pipe_capacity" => values.(Pipes_opt_sizes))
    Pipes_df_results = DataFrame("Pipeline_lon1" => lon_1, "Pipeline_lat1" => lat_1, "Pipeline_lon2" => lon_2, "Pipeline_lat2" => lat_2, "Pipe_capacity" => values.(Pipes_opt_sizes))

    if MPEC .== true
        file_pipelines = "./Output data files/CSV intermediaries $(detail_level)/MPEC/Results_pipelines_$(Scenario_name)_$(CO2_tax)_$(Subcase_name).csv"
    else
        file_pipelines = "./Output data files/CSV intermediaries $(detail_level)/Results_pipelines_$(Scenario_name)_$(CO2_tax)_$(Subcase_name).csv"
    end

    CSV.write(file_pipelines, Pipes_df_results)

    # XLSX.openxlsx(results_pipes_file, mode="rw") do xf
    #     SheetName = "$(Scenario_name)_$(Region)_$(CO2_tax)"
    #     try 
    #         XLSX.addsheet!(xf, SheetName)
    #     catch 
    #     end
    #     sheet = xf[SheetName]
    #     XLSX.writetable!(sheet,Pipes_df_results; anchor_cell=XLSX.CellRef("A1")) # NOTE: if shorter df --> some rows of previous run might still be included in excel table. (not yet resolved nicely: https://felipenoris.github.io/XLSX.jl/stable/api/)
    # end
    
return 
end

function storage_results_save(Scenario_name::String, Region::String, CO2_tax::Int64)
    
    Storages_of_in = vcat(Storage_inland, Storage_offshore)
    Storages_of_in[:, "Stored_vol_node_origin"] = zeros(length(Storages_of_in[:,"Storage_name"]))


    for (key, value) in zip(keys(q_inj_inl), values(q_inj_inl)) 
        global Storages_of_in[Storages_of_in[:, "Node_id"] .== key[1], "Stored_vol_node_origin"] = [values.(q_inj_inl)[key[1]]]
    end

    for (key, value) in zip(keys(q_inj_off), values(q_inj_off)) 
       global Storages_of_in[Storages_of_in[:, "Node_id"] .== key[1], "Stored_vol_node_origin"] = [values.(q_inj_off)[key[1]]]
    end


    if MPEC .== true
        file_storages = "./Output data files/CSV intermediaries $(detail_level)/MPEC/Results_storages_$(Scenario_name)_$(CO2_tax)_$(Subcase_name).csv"
    else 
        file_storages = "./Output data files/CSV intermediaries $(detail_level)/Results_storages_$(Scenario_name)_$(CO2_tax)_$(Subcase_name).csv"
    end

    CSV.write(file_storages, Storages_of_in)

    return Storages_of_in
end

function storage_results_extract(Scenario_name::String, Subcase_name::String, CO2_tax::Int64)

    # Storage_lines = Pipelines[startswith.(Pipelines.Node_origin, "Si") .| 
    #                                            startswith.(Pipelines.Node_origin, "So"), 
    #                                            :]
    # Storage_lines[:, "Stored_vol_node_origin"] = zeros(length(Storage_lines[:,"Pipe_name"]))
    # Storages_of_in = vcat(Storage_inland, Storage_offshore)
    # Storages_of_in[:, "Stored_vol_node_origin"] = zeros(length(Storages_of_in[:,"Storage_name"]))

    # Pipes_opt_co_na, Pipes_opt_sizes = pipeline_results_extract(results_pipes_file::String, Scenario_name::String, Region::String, CO2_tax::Int64)
    # Pipes_df_results = DataFrame("Coordinates" => Pipes_opt_co_na, "Size" => Pipes_opt_sizes) 

    # for row in eachrow(Storages_of_in)
    #     Lat_o = row.Lat
    #     # Lat_d = row.Latitude_destination
    #     Lon_o = row.Lon
    #     # Lon_d = row.Longitude_destination
    #     Index_pipe = findfirst(coord -> (coord[1] == Lon_o) .& (coord[3] == Lat_o), Pipes_df_results.Coordinates)
    #     size_value = isnothing(Index_pipe) ? 0.0 : Pipes_df_results.Size[Index_pipe]
    #     row.Stored_vol_node_origin = size_value
    #     print(size_value)
    # end

    try 
        if MPEC == true 
            results_storages_file_csv = "./Output data files/CSV intermediaries $(detail_level)/MPEC/Results_storages_$(Scenario_name)_$(CO2_tax)_$(Subcase_name).csv"
        else
            results_storages_file_csv = "./Output data files/CSV intermediaries $(detail_level)/Results_storages_$(Scenario_name)_$(CO2_tax)_$(Subcase_name).csv"
        end
        global Storages_of_in = CSV.read(results_storages_file_csv, DataFrame)
        # Pipes_df_results = DataFrame(XLSX.readtable(results_pipes_file, "$(Scenario_name)_$(Region)_$(CO2_tax)"))


    catch e 
        println("An error occurred: ", e)
        println("Setting default values for scenario: ", Scenario_name, " and year: ", Scenario_horizon, " and tax: ", CO2_tax)
        Storages_of_in = missing 
    end
     return Storages_of_in
end


function pipeline_results_extract(Scenario_name::String, Subcase_name::String, CO2_tax::Int64)
    try 
        if MPEC == true 
            results_pipes_file_csv = "./Output data files/CSV intermediaries $(detail_level)/MPEC/Results_pipelines_$(Scenario_name)_$(CO2_tax)_$(Subcase_name).csv"
        else
            results_pipes_file_csv = "./Output data files/CSV intermediaries $(detail_level)/Results_pipelines_$(Scenario_name)_$(CO2_tax)_$(Subcase_name).csv"
        end
        Pipes_df_results = CSV.read(results_pipes_file_csv, DataFrame)
        # Pipes_df_results = DataFrame(XLSX.readtable(results_pipes_file, "$(Scenario_name)_$(Region)_$(CO2_tax)"))
        global Pipes_opt_co_na = [[Pipes_df_results[i, "Pipeline_lon1"] Pipes_df_results[i, "Pipeline_lat1"]; Pipes_df_results[i, "Pipeline_lon2"] Pipes_df_results[i, "Pipeline_lat2"]] for i in 1:length(Pipes_df_results[:,1])]
        global Pipes_opt_sizes = Pipes_df_results[:, "Pipe_capacity"]

    catch e 
        println("An error occurred: ", e)
        println("Setting default values for scenario: ", Scenario_name, " and year: ", Scenario_horizon, " and tax: ", CO2_tax)
        Pipes_opt_co_na = missing 
        Pipes_opt_sizes = missing 
    end

return Pipes_opt_co_na, Pipes_opt_sizes
end

function key_results_extract(Scenario_name::String, Subcase_name::String,  CO2_tax::Int64)
    if MPEC == true
        results_stats_file_csv = "./Output data files/CSV intermediaries $(detail_level)/MPEC/Results_statistics_$(Scenario_name)_$(CO2_tax)_$(Subcase_name).csv"
    else 
        results_stats_file_csv = "./Output data files/CSV intermediaries $(detail_level)/Results_statistics_$(Scenario_name)_$(CO2_tax)_$(Subcase_name).csv"
    end
    Key_df_results = CSV.read(results_stats_file_csv, DataFrame)
    # Key_df_results =  DataFrame(XLSX.readtable(results_stats_file, "$(Scenario_name)_$(Region)_$(CO2_tax)"))
    Key_df_results.Values = [try parse(Float64, x) catch  e convert(String, x) end for x in Key_df_results[:, "Values"]]

return Key_df_results
end

function industry_results_extract(Scenario_name::String, Subcase_name::String, CO2_tax::Int64)

    if MPEC == true 
        file_industry = "./Output data files/CSV intermediaries $(detail_level)/MPEC/Results_industry_$(Scenario_name)_$(CO2_tax)_$(Subcase_name).csv"
    else 
        file_industry = "./Output data files/CSV intermediaries $(detail_level)/Results_industry_$(Scenario_name)_$(CO2_tax)_$(Subcase_name).csv"
    end

    Industry_connection_results = CSV.read(file_industry, DataFrame) 

    return Industry_connection_results 
end


function total_system_costs(Scenario_name, CO2_tax)
    Scenario_name_input = Scenario_name
    Emitters =  import_data_industry(CO2_tax::Any, Scenario_name::String, Scenario_horizon::Int64)
    EMITTERS = CCTS_element_selection(Region::String)

    if MPEC == false     
        include("parameters.jl")    # run all the parameters of the script
        file_industry = "./Output data files/CSV intermediaries $(detail_level)/Results_industry_$(Scenario_name)_$(CO2_tax)_$(Subcase_name).csv"
        file_stats  ="./Output data files/CSV intermediaries $(detail_level)/Results_statistics_$(Scenario_name)_$(CO2_tax)_$(Subcase_name).csv"
        Industry_connection_results = CSV.read(file_industry, DataFrame)
        Stats_df = CSV.read(file_stats, DataFrame)
    
        cc_emitter =  Dict(e => try Industry_connection_results[Industry_connection_results[:, "Emitters"] .== e, "Bin_connection"][1] catch skip end for e in EMITTERS)
        Avg_ts_string = Stats_df[Stats_df[:, "Parameters"] .== "Average T&S costs", "Values"][1]
        Avg_ts = parse(Float64, Avg_ts_string)
        Vol_ts_string = Stats_df[Stats_df[:, "Parameters"] .== "Total capture volume", "Values"][1]
        Vol_ts = parse(Float64, Vol_ts_string)
        Tot_system_cost = sum((1-cc_emitter[n]).*(CAPEX_noCC[n] .+ OPEX_noCC[n]) .+ cc_emitter[n].*(CAPEX_1[n] .+ OPEX_1[n]) for n in EMITTERS) + Vol_ts * Avg_ts 
        
    else 
        file_industry = "./Output data files/CSV intermediaries $(detail_level)/MPEC/Results_industry_$(Scenario_name)_$(CO2_tax)_$(Subcase_name).csv"
        file_stats  ="./Output data files/CSV intermediaries $(detail_level)/MPEC/Results_statistics_$(Scenario_name)_$(CO2_tax)_$(Subcase_name).csv"
        filename_tariff = "./Output data files/CSV intermediaries $(detail_level)/MPEC/Results_tariff_$(Scenario_name)_$(CO2_tax)_$(Subcase_name).csv"

        Industry_connection_results = CSV.read(file_industry, DataFrame)
        Stats_df = CSV.read(file_stats, DataFrame)
        Tariff_df = CSV.read(filename_tariff, DataFrame)

        cc_emitter =  Dict(e => try Industry_connection_results[Industry_connection_results[:, "Emitters"] .== e, "Bin_connection"][1] catch skip end for e in EMITTERS)
        Avg_ts_string = Stats_df[Stats_df[:, "Parameters"] .== "Average T&S costs", "Values"][1]
        Avg_ts = parse(Float64, Avg_ts_string)
        Vol_ts_string = Stats_df[Stats_df[:, "Parameters"] .== "Total capture volume", "Values"][1]
        Vol_ts = parse(Float64, Vol_ts_string)

        
        Tot_system_cost = sum((1-cc_emitter[n]).*(CAPEX_noCC[n] .+ OPEX_noCC[n]) .+ cc_emitter[n].*(CAPEX_1[n] .+ OPEX_1[n]) .+ cc_emitter[n] * Tariff_df[Tariff_df[:,"Emitter"] .==n, "Tariff"] * TOT_capture_1_CO2[n] for n in EMITTERS)  
    end 
end


function HPC_result_extraction(results_pipes_file_HPC::String, results_stats_file_HPC::String, results_industry_file_HPC::String, Scenario_name_vect, Scenario_horizon_vect, CO2_tax::Int64, plotting::Bool)
    All_key_results_df = DataFrame(
        "Scenario name" => repeat(Scenario_name_vect, inner=(length(Scenario_horizon_vect),)), 
        "Scenario year" => repeat(Scenario_horizon_vect, length(Scenario_name_vect)),
        "Max total connections" => zeros(length(Scenario_horizon_vect).*length(Scenario_name_vect)),
        "Optimised connections" => zeros(length(Scenario_horizon_vect).*length(Scenario_name_vect)),
        "Total capture potential" => zeros(length(Scenario_horizon_vect).*length(Scenario_name_vect)),
        "Total capture volume" =>zeros(length(Scenario_horizon_vect).*length(Scenario_name_vect)),
        "Total capture volume fossil" =>zeros(length(Scenario_horizon_vect).*length(Scenario_name_vect)),
        "Total capture volume bio" => zeros(length(Scenario_horizon_vect).*length(Scenario_name_vect)),
        "Biomass use" => zeros(length(Scenario_horizon_vect).*length(Scenario_name_vect)),
        "Average T&S costs" => zeros(length(Scenario_horizon_vect).*length(Scenario_name_vect)), 
        "MIPgap" => zeros(length(Scenario_horizon_vect).*length(Scenario_name_vect)), 
        "Total costs" => zeros(length(Scenario_horizon_vect).*length(Scenario_name_vect)), 
        "Pipeline cost" => zeros(length(Scenario_horizon_vect).*length(Scenario_name_vect)), 
        "Storage cost" => zeros(length(Scenario_horizon_vect).*length(Scenario_name_vect)), 
        "Booster cost" => zeros(length(Scenario_horizon_vect).*length(Scenario_name_vect)), 
        )
    Scenario_name_text_vect = ["CDR credits", "No CDR", "Biomass restricted", "Industry exit (CDR)", "Industry exit (No CDR)"]
    i = 0

    for SN in Scenario_name_vect
        i = i+1
        for SH in Scenario_horizon_vect
            global Scenario_name = SN
            global Scenario_horizon = SH
            global Figure_name = ""
            global title_plot = Scenario_name_text_vect[i]
            global Pipes_opt_co_na, Pipes_opt_sizes = pipeline_results_extract(Scenario_name::String, Subcase_name::String, CO2_tax::Int64)
            # All_industry_results_df = industry_results_extract(industry_data_file::String, results_industry_file_HPC::String, results_stats_file_HPC::String, Scenario_name_vect, Scenario_horizon_vect)
            Key_df_results = key_results_extract(Scenario_name::String, Subcase_name::String, CO2_tax::Int64)

            try 

                All_key_results_df[(All_key_results_df[:,"Scenario name"] .==Scenario_name) .& (All_key_results_df[:,"Scenario year"] .==Scenario_horizon), "Max total connections"] = Key_df_results[Key_df_results[:, "Parameters"] .== "Max total connections", "Values"]
                All_key_results_df[(All_key_results_df[:,"Scenario name"] .==Scenario_name) .& (All_key_results_df[:,"Scenario year"] .==Scenario_horizon), "Optimised connections"] = Key_df_results[Key_df_results[:, "Parameters"] .== "Optimised connections", "Values"]
                All_key_results_df[(All_key_results_df[:,"Scenario name"] .==Scenario_name) .& (All_key_results_df[:,"Scenario year"] .==Scenario_horizon), "Total capture potential"] = Key_df_results[Key_df_results[:, "Parameters"] .== "Total capture potential", "Values"]
                All_key_results_df[(All_key_results_df[:,"Scenario name"] .==Scenario_name) .& (All_key_results_df[:,"Scenario year"] .==Scenario_horizon), "Total capture volume"] = Key_df_results[Key_df_results[:, "Parameters"] .== "Total capture volume", "Values"]
                All_key_results_df[(All_key_results_df[:,"Scenario name"] .==Scenario_name) .& (All_key_results_df[:,"Scenario year"] .==Scenario_horizon), "Total capture volume bio"] = Key_df_results[Key_df_results[:, "Parameters"] .== "Total capture volume bio", "Values"]
                All_key_results_df[(All_key_results_df[:,"Scenario name"] .==Scenario_name) .& (All_key_results_df[:,"Scenario year"] .==Scenario_horizon), "Total capture volume fossil"] = Key_df_results[Key_df_results[:, "Parameters"] .== "Total capture volume fossil", "Values"]
                All_key_results_df[(All_key_results_df[:,"Scenario name"] .==Scenario_name) .& (All_key_results_df[:,"Scenario year"] .==Scenario_horizon), "Biomass use"] = Key_df_results[Key_df_results[:, "Parameters"] .== "Biomass use", "Values"]
                All_key_results_df[(All_key_results_df[:,"Scenario name"] .==Scenario_name) .& (All_key_results_df[:,"Scenario year"] .==Scenario_horizon), "Average T&S costs"] = Key_df_results[Key_df_results[:, "Parameters"] .== "Average T&S costs", "Values"]
                All_key_results_df[(All_key_results_df[:,"Scenario name"] .==Scenario_name) .& (All_key_results_df[:,"Scenario year"] .==Scenario_horizon), "Total costs"] = Key_df_results[Key_df_results[:, "Parameters"] .== "Total costs", "Values"]
                All_key_results_df[(All_key_results_df[:,"Scenario name"] .==Scenario_name) .& (All_key_results_df[:,"Scenario year"] .==Scenario_horizon), "Pipeline cost"] = Key_df_results[Key_df_results[:, "Parameters"] .== "Pipeline cost", "Values"]
                All_key_results_df[(All_key_results_df[:,"Scenario name"] .==Scenario_name) .& (All_key_results_df[:,"Scenario year"] .==Scenario_horizon), "Storage cost"] = Key_df_results[Key_df_results[:, "Parameters"] .== "Storage cost", "Values"]
                All_key_results_df[(All_key_results_df[:,"Scenario name"] .==Scenario_name) .& (All_key_results_df[:,"Scenario year"] .==Scenario_horizon), "Booster cost"] = Key_df_results[Key_df_results[:, "Parameters"] .== "Booster cost", "Values"]

            catch e
                # Handle exceptions: Log the error and set default values
                println("An error occurred for one of the result values: ", e)
                println("Setting default values for scenario: ", Scenario_name, " and year: ", Scenario_horizon, "and tax: ", CO2_tax)
            
                All_key_results_df[(All_key_results_df[:,"Scenario name"] .==Scenario_name) .& (All_key_results_df[:,"Scenario year"] .==Scenario_horizon), "Max total connections"] = [-0.0]
                All_key_results_df[(All_key_results_df[:,"Scenario name"] .==Scenario_name) .& (All_key_results_df[:,"Scenario year"] .==Scenario_horizon), "Optimised connections"] = [-0.0]
                All_key_results_df[(All_key_results_df[:,"Scenario name"] .==Scenario_name) .& (All_key_results_df[:,"Scenario year"] .==Scenario_horizon), "Total capture potential"] = [-0.0]
                All_key_results_df[(All_key_results_df[:,"Scenario name"] .==Scenario_name) .& (All_key_results_df[:,"Scenario year"] .==Scenario_horizon), "Total capture volume"] = [-0.0]
                All_key_results_df[(All_key_results_df[:,"Scenario name"] .==Scenario_name) .& (All_key_results_df[:,"Scenario year"] .==Scenario_horizon), "Total capture volume bio"] =[-0.0]
                All_key_results_df[(All_key_results_df[:,"Scenario name"] .==Scenario_name) .& (All_key_results_df[:,"Scenario year"] .==Scenario_horizon), "Total capture volume fossil"] = [-0.0]
                All_key_results_df[(All_key_results_df[:,"Scenario name"] .==Scenario_name) .& (All_key_results_df[:,"Scenario year"] .==Scenario_horizon), "Average T&S costs"] = [-0.0]
                All_key_results_df[(All_key_results_df[:,"Scenario name"] .==Scenario_name) .& (All_key_results_df[:,"Scenario year"] .==Scenario_horizon), "Biomass use"] =  [-0.0]
                All_key_results_df[(All_key_results_df[:,"Scenario name"] .==Scenario_name) .& (All_key_results_df[:,"Scenario year"] .==Scenario_horizon), "Total costs"] = [-0.0]
                All_key_results_df[(All_key_results_df[:,"Scenario name"] .==Scenario_name) .& (All_key_results_df[:,"Scenario year"] .==Scenario_horizon), "Pipeline cost"] = [-0.0]
                All_key_results_df[(All_key_results_df[:,"Scenario name"] .==Scenario_name) .& (All_key_results_df[:,"Scenario year"] .==Scenario_horizon), "Storage cost"] = [-0.0]
                All_key_results_df[(All_key_results_df[:,"Scenario name"] .==Scenario_name) .& (All_key_results_df[:,"Scenario year"] .==Scenario_horizon), "Booster cost"] = [-0.0]
            end 
            try 
                All_key_results_df[(All_key_results_df[:,"Scenario name"] .==Scenario_name) .& (All_key_results_df[:,"Scenario year"] .==Scenario_horizon), "MIPgap"] = Key_df_results[Key_df_results[:, "Parameters"] .== "MIPgap", "Values"]
            catch e
                println("An error occurred for the MIPGap: ", e)
                println("Setting default values for scenario: ", Scenario_name, " and year: ", Scenario_horizon, " and tax: ", CO2_tax)
                All_key_results_df[(All_key_results_df[:,"Scenario name"] .==Scenario_name) .& (All_key_results_df[:,"Scenario year"] .==Scenario_horizon), "MIPgap"] = [-0.0]
            end
            global Pipes_opt_co_na
            global Pipes_opt_sizes
            #global All_industry_results_df =  industry_results_extract(industry_data_file_HPC::String, results_industry_file_HPC::String, results_stats_file_HPC::String, Scenario_name_vect, Scenario_horizon_vect)            # global All_industry_results_df
            try 
                if MPEC == true 
                    file_industry = "./Output data files/CSV intermediaries $(detail_level)/MPEC/Results_industry_$(Scenario_name)_$(CO2_tax)_$(Subcase_name).csv"
                else
                file_industry = "./Output data files/CSV intermediaries $(detail_level)/Results_industry_$(Scenario_name)_$(CO2_tax)_$(Subcase_name).csv"
                end
                Industry_connection_results = CSV.read(file_industry, DataFrame)
                global cc_emitter = Dict(Industry_connection_results[e, "Emitters"] => Industry_connection_results[e, "Bin_connection"] for e in 1:1:length(Industry_connection_results[:,"Bin_connection"]))
            catch e 
                println("An error occurred for the pipeline connections: ", e)
                println("Setting default values for scenario: ", Scenario_name, " and year: ", Scenario_horizon, " and tax: ", CO2_tax)
                global cc_emitter = missing 
            end

            
            if plotting .== true
                visualisation_py(shapefile_eu, Figure_name, title_plot)
            else 
                skip 
            end
        end
        if plotting .== true 
            # product_plots(All_industry_results_df)
            # total_costs_plot(All_key_results_df, Scenario_name_vect, Scenario_horizon_vect)
        end 
    end
    return   All_key_results_df
end



