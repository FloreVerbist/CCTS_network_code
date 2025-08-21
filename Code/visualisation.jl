



function TandS_fraction_cost_plot(absolute::Bool)



    # variables_extract(model_1)
    # c_transport_actual = sum(f_transport(q_pipe_tot[pc, p])*Pipe_distance[p] for pc in PIECES, p in PIPES)
    # Q_tot = sum(q_inj_off.data)+ sum(q_inj_inl.data)
    # print("Piecewise error (Actual - Piecewise): $((c_transport_actual - c_transport)/Q_tot)----EUR/tCO2/yr")

    All_key_results_df =  HPC_result_extraction(results_pipes_Trilateral_file_HPC::String, results_stats_Trilateral_file_HPC::String, results_industry_Trilateral_file_HPC::String, Scenario_name_vect, Scenario_horizon_vect, CO2_tax, (plotting=false; plotting))
    c_transport = All_key_results_df[:, "Pipeline cost"]
    c_storage = All_key_results_df[:, "Storage cost"]
    c_booster = All_key_results_df[:, "Booster cost"]
    Q_tot = All_key_results_df[:, "Total capture volume"]
    Colors = ["lightcyan4" "powderblue" "steelblue3"]
    c_total = c_transport + c_storage + c_booster

    if absolute == true
        LC_P = c_transport./Q_tot
        LC_S = c_storage./Q_tot
        LC_BP = c_booster./Q_tot
        LC_S[3] = LC_P[3] = LC_BP[3] = 0.0 
        Ylab = "Absolute T&S costs [EUR/tCO2]"
        LPos = :topleft
    else
        LC_P = c_transport./c_total .* 100
        LC_S = c_storage./c_total .* 100
        LC_BP = c_booster./c_total .* 100
        LC_S[3] = LC_P[3] = LC_BP[3] = 0.0 
        Ylab = "Relative T&S costs  [%]"
        LPos = false
    end
    group_labels = ["Cost pipelines", "Cost storages", "Cost booster pumps"]
    scenario_plot_names = ["EU based - No CDR", "EU based - CDR", "EU exit - No CDR", "EU exit - CDR"]
    ymax  = maximum(LC_P+LC_S+LC_BP)
    fig = Plots.plot(ylim = (0, ymax + 5), xlim = (0, 5))
    yvalue = vec(hcat(LC_P, LC_S, LC_BP)')
    x_positions = repeat([1.0, 2.0, 3.0, 4.0], inner=3)
    groupedbar!(x_positions, yvalue, group = repeat(group_labels, 4), bar_position = :stack, bar_width = 0.5,  xtick = ([1.0, 2.0, 3.0, 4.0] ,scenario_plot_names),  ylabel = Ylab, legend= LPos, title="" , color =Colors)

    Plots.plot!(twiny(fig), label=false, xticks = false)
    Plots.plot!(twinx(fig), label=false, yticks = false)
    Plots.plot!(fig, size=(800, 500), xtickfontsize = 18, ytickfont = font(18), legendfont = font(18), guidefontsize = 18, xrotation = 45)






    filename_string = "./Figures/TandS_cost_fractions.svg"
    Plots.savefig(fig, filename_string)
    display(fig)

end



function visualisation(Pipes_opt_co_na, Pipes_opt_sizes, NUTS_0, Figure_name, Potential_routes = false)
    

    Pipes_sets =[mat2ds(Pipe_coordinates[i], Pipe_id[i]) for i in 1:1:length(Pipelines[:,1])];
    # Slines_sets = [mat2ds(Sline_coordinates[i], Sline_names[i]) for i in 1:1:length(Shipping[:,1])];
    Nodes_sets = mat2ds(Nodes_coordinates, Nodes_id);
    Clusters = mat2ds(Cluster_coordinates, Cluster_id);
    Routing = mat2ds(Routing_nodes_coordinates, Routing_nodes_id);
    Storage = mat2ds(Storages_coordinates, Storages_id);
    
    
    D_opt_pipe = (((Pipes_opt_sizes).*(4/pi)).^2 .* (0.015 ./(2*850*0.3))).^(2/5).*100  #in cm q * (4/pi)^2 * f/ (2 * rho * delta_p/L) ] ^(2/5)
    print(maximum(D_opt_pipe))
    MIN_lines = minimum(values.(Pipes_opt_sizes))
    MAX_lines = maximum(values.(Pipes_opt_sizes))

    scaled_pipe_size = Pipes_opt_sizes ./ MAX_lines .+ 0.4
    scaled_pipe_size = (MIN_lines .+ ((Pipes_opt_sizes .- MIN_lines) .* (MAX_lines-MIN_lines))./(MAX_lines -MIN_lines)) ./ MAX_lines .+ 0.4

    Region = "-2/35/22/60+r"  #""2/49/6.5/53+r",
    # The image will be downloaded automatically
    Country_vec = [(country=N_code,
    pen=(0.1,:grey), fill=:pink) for N_code in NUTS_0]
    Country_tuple = Tuple(N for N in Country_vec)
    # regions = Shapefile.Table(shapefile_eu) 
    # nuts2_region = filter(row -> row.NUTS_ID .== NUTS_2[1], regions)


    Figure = coast(region= Region,
            proj=(name=:laea, center=[10,50]),
            frame=:ag,
            res=:high,
            area=500,
            shore=:thin,
            borders=1,
            DCW= Country_tuple,
            figsize=10)




    for (item,pipe_opt) in enumerate(Pipes_opt_co_na)
        plot!(pipe_opt, connection="p", lw=scaled_pipe_size[item], lc=:red)
    end

    
    GMT.scatter!(float.(Cluster_coordinates[:,2]), float.(Cluster_coordinates[:,1]),
                    fmt=:png,
                    marker=:circle,
                    markeredgecolor=0,
                    size=0.05,
                    markerfacecolor=:green)

    GMT.scatter!(float.(Cement_coordinates[:,2]), float.(Cement_coordinates[:,1]),
                    fmt=:png,
                    marker=:circle,
                    markeredgecolor=:black,
                    size=0.08,
                    markerfacecolor=:royalblue3)
    GMT.scatter!(float.(Chemical_coordinates[:,2]), float.(Chemical_coordinates[:,1]),
                    fmt=:png,
                    marker=:circle,
                    markeredgecolor=:black,
                    size=0.08,
                    markerfacecolor=:brown3)
    GMT.scatter!(float.(Fertilisers_coordinates[:,2]), float.(Fertilisers_coordinates[:,1]),
                    fmt=:png,
                    marker=:circle,
                    markeredgecolor=:black,
                    size=0.08,
                    markerfacecolor=:yellow2)
    GMT.scatter!(float.(Glass_coordinates[:,2]), float.(Glass_coordinates[:,1]),
                    fmt=:png,
                    marker=:circle,
                    markeredgecolor=:black,
                    size=0.08,
                    markerfacecolor=:darkorange1)
    GMT.scatter!(float.(Refineries_coordinates[:,2]), float.(Refineries_coordinates[:,1]),
                    fmt=:png,
                    marker=:circle,
                    markeredgecolor=:black,
                    size=0.08,
                    markerfacecolor=:ivory4)
    GMT.scatter!(float.(Steel_coordinates[:,2]), float.(Steel_coordinates[:,1]),
                    fmt=:png,
                    marker=:circle,
                    markeredgecolor=:black,
                    size=0.08,
                    markerfacecolor=:orchid1)

    GMT.scatter!(float.(Terminal_coordinates[:,2]), float.(Terminal_coordinates[:,1]),
                    fmt=:png,
                    marker=:rect,
                    markeredgecolor=0,
                    size=0.08,
                    markerfacecolor=:lightblue)
    GMT.scatter!(float.(Routing_nodes_coordinates[:,2]), float.(Routing_nodes_coordinates[:,1]),
                    fmt=:png,
                    marker=:circle,
                    markeredgecolor=0,
                    size=0.02,
                    markerfacecolor=:black)
    GMT.scatter!(float.(Storages_coordinates[:,2]), float.(Storages_coordinates[:,1]),
                    fmt=:png,
                    marker=:rect,
                    markeredgecolor=0,
                    size=0.1,
                    markerfacecolor=:springgreen3) 
    #plot!(dea_region.geometry, color=:pink, label="")


    try 
        if Potential_routes == true 
            for Pipeline in Pipes_sets
                plot!(Pipeline, connection="p", lw=0.5, lc=:grey)
            end
        else skip 
        end
    catch 
    end




    # for (item,sline_opt) in enumerate(Sline_opt_co_na)
    #     plot!(sline_opt, connection="p", lw=scaled_sline_size[item], lc=:skyblue2, marker=:circ, ms=0.2, mc=:white, alpha = 0.5)
    # end

    makecpt("-Cpanoply -T-8/8 > tt.cpt")

    # for legends, see: https://www.generic-mapping-tools.org/GMTjl_doc/examples/legends/01_legends/#example_18264910314438066529
    legend!((
            vspace=-0.25,
            header=(text="Legend", font=(14,"Times-Roman")),
            hline=(pen=1, offset=0.5),
            ncolumns=2,
            vline=(pen=1, offset=0),
            symbolcement= (marker=:circ,    size=0.15, dx_left=0.25, fill=:royalblue3, pen=0.5, dx_right=0.75, text="Cement"),
            symbolchemicals= (marker=:circ,    size=0.15, dx_left=0.25, fill=:brown3, pen=0.5, dx_right=0.75, text="Chemicals"),
            symbolfertilisers = (marker=:circ,    size=0.15, dx_left=0.25, fill=:yellow2, pen=0.5, dx_right=0.75, text="Fertilisers"),
            symbolglass = (marker=:circ,    size=0.15, dx_left=0.25, fill=:darkorange1, pen=0.5, dx_right=0.75, text="Glass"),
            symbolrefineries = (marker=:circ,    size=0.15, dx_left=0.25, fill=:ivory4, pen=0.5, dx_right=0.75, text="Refineries"),
            symbolsteel= (marker=:circ,    size=0.15, dx_left=0.25, fill=:orchid1, pen=0.5, dx_right=0.75, text="Steel"),
            # symbol3=(marker=:circ,    size=0.15, dx_left=0.25, fill=:green, pen=0.5, dx_right=0.75, text="Industry cluster"),
            symbol5=(marker=:circ,    size=0.1, dx_left=0.25, fill= :black, dx_right=0.75, text="Routing nodes"),
            symbol2=(marker=:rect,    size=0.4, dx_left=0.25, fill=:pink, pen=0.1, dx_right=0.75, text="Considered countries"),
            symbol7=(marker=:rect,    size=0.15, dx_left=0.25, fill= :lightblue, pen=0.5, dx_right=0.75, text="Terminals"),
            symbol4=(marker="-",      size=0.4, dx_left=0.25, pen=(0.25, :grey), dx_right=0.75, text="Potential routes"),
            symbol1=(marker=:rect,    size=0.2, dx_left=0.25, fill=:springgreen3, pen=0.5, dx_right=0.75, text="Storage site"),
            symbol6=(marker="-",      size=0.4, dx_left=0.25, pen=(1, :red), dx_right=0.75, text="Optimised route"),
            hline2=(pen=1, offset=0.5),
            vline2=(pen=1, offset=0),
            ncolumns2=1,
            map_scale=(lon=5, lat=5, length="600+u+f"),
            vspace2=0.13,
            text1="(Draft results)",
            vspace4=0.25,
            label=(txt="@%5%Verbist et al., 2024@%%", justify=:R, font=(9, "Times-Roman")),
           ),
           region= Region, pos=(paper=(11.0,11), width=9, justify=:BL, spacing=1.2),
           clearance=(0.25,0.25), box=(pen=0.5, fill=:azure1)
          )   


        filename_string = "./Figures/$(Figure_name).png"


    return text!(Nodes_sets, offset=0.3, font=(5,:Black), show=true, savefig= filename_string)
end

# Define the base pattern


# Function to generate the full sequence
function generate_sequence(n_repeats::Int, base_pattern)
    result = Float64[]
    #base_pattern = [2, 2.5, 3, 3.5]
    # Repeat the base pattern with increments
    for i in 0:n_repeats-1
        result = vcat(result, base_pattern .+ i*3)  # Add i to each element of the base pattern
    end
    
    return result
end

function costs_plots(Scenario_name::String, Scenario_horizon::Int64)

    global Emitters = import_data_industry(CO2_tax::Any, Scenario_name::String, Scenario_horizon::Int64)
    Key_results_df =  key_results_extract(results_stats_file::String, Scenario_name::String, Region::String,  CO2_tax::Int64)

    Product_names = sort!(unique(Emitters[:, "Product_route_name"]))  
    Route_name_1 = [Emitters[Emitters[:,"Product_route_name"] .== name, "Route_name_1" ][1] for name in Product_names]
    Route_name_noCC = [Emitters[Emitters[:,"Product_route_name"] .== name, "Route_name_noCC" ][1] for name in Product_names]
    Capex_1_EURptpa = [Emitters[Emitters[:,"Product_route_name"] .== name, "Capex_1_EURptpa" ][1] for name in Product_names]
    Capex_noCC_EURptpa = [Emitters[Emitters[:,"Product_route_name"] .== name, "Capex_noCC_EURptpa" ][1] for name in Product_names]
    Opex_noTandS_1_EURptpa = [Emitters[Emitters[:,"Product_route_name"] .== name, "Opex_noTandS_1_EURptpa" ][1] for name in Product_names]
    Opex_noTandS_noCC_EURptpa = [Emitters[Emitters[:,"Product_route_name"] .== name, "Opex_noTandS_noCC_EURptpa" ][1] for name in Product_names]
    CO2_allowance_cost_1_EURpt = [Emitters[Emitters[:,"Product_route_name"] .== name, "CO2_allowance_cost_1_EURpt" ][1] for name in Product_names]
    CO2_allowance_cost_noCC_EURpt = [Emitters[Emitters[:,"Product_route_name"] .== name, "direct_emission_noCC_tco2_t" ][1] for name in Product_names] * CO2_tax
    Opex_energy_1_EURptpa = Opex_noTandS_1_EURptpa - CO2_allowance_cost_1_EURpt
    Opex_energy_noCC_EURptpa = Opex_noTandS_noCC_EURptpa - CO2_allowance_cost_noCC_EURpt
    Avg_TandS_costs = Key_results_df[Key_results_df[:, "Parameters"] .== "Average T&S costs", "Values"][1] # EUR/tCO2
    CO2_TandS_product_cost = [abs(Emitters[Emitters[:,"Product_route_name"] .== name, "Captured_CO2_1_tCO2ptpa" ][1]) for name in Product_names] * Avg_TandS_costs # EUR/tp
    CO2_TandS_product_cost_noCC =  CO2_TandS_product_cost * 0 
    Cost_labels = ["CAPEX", "OPEX", "ETS COSTS", "T&S FEE (AVG)"]
    Costs_route_1 = vcat(Capex_1_EURptpa, vcat(Opex_energy_1_EURptpa, vcat(CO2_allowance_cost_1_EURpt,  CO2_TandS_product_cost)))
    Costs_route_noCC = vcat(Capex_noCC_EURptpa, vcat(Opex_energy_noCC_EURptpa, vcat(CO2_allowance_cost_noCC_EURpt,  CO2_TandS_product_cost_noCC)))

    # y_data =     vcat(Costs_route_1, Costs_route_noCC)

    Capex_routes = vcat(Capex_1_EURptpa, Capex_noCC_EURptpa)
    Opex_routes = vcat(Opex_energy_1_EURptpa, Opex_energy_noCC_EURptpa)
    CO2_tax_routes = vcat(CO2_allowance_cost_1_EURpt, CO2_allowance_cost_noCC_EURpt)
    Avg_TandS_routes = vcat(CO2_TandS_product_cost, CO2_TandS_product_cost_noCC)

    Totex_routes = Capex_routes + Opex_routes+ CO2_tax_routes +Avg_TandS_routes
    routes = vcat(Route_name_1, Route_name_noCC)
    ydata  = vcat(Capex_routes, vcat(Opex_routes, vcat(CO2_tax_routes,  Avg_TandS_routes)))
    # xdata = repeat(repeat(Product_names, inner=2),4)
    # xdata  = repeat(vec(vcat(Route_name_1, Route_name_noCC)),4)
    # basepattern = [1, 2]
    # xvector = vcat([basepattern .+ 3*i for i in 0:1:(length(Product_names)-1)]...)
    xvector_1 =  vcat([1 .+ 3*i for i in 0:1:(length(Product_names)-1)]...)
    xvector_noCC =  vcat([2 .+ 3*i for i in 0:1:(length(Product_names)-1)]...)
    xvector = vcat(xvector_1, xvector_noCC)
    # Plot production costs 

    # Pipes_opt_co_na, Pipes_opt_sizes = pipeline_results_extract(results_pipes_file_HPC::String, Scenario_name::String, Scenario_horizon::Int64, CO2_tax::Int64)
    Industry_connection_results =  DataFrame(XLSX.readtable(results_industry_file_HPC,  "$(Scenario_name)_$(Scenario_horizon)_$(CO2_tax)"))
    cc_emitter = Dict(Industry_connection_results[e, "Emitters"] => Industry_connection_results[e, "Bin_connection"] for e in 1:1:length(Industry_connection_results[:,"Bin_connection"]))

    Emitters_modelled = Dict(e =>  (Emitters[Emitters[:,"Emitter_id"] .==e, "Lon"][1],  Emitters[Emitters[:,"Emitter_id"] .==e, "Lat"][1]) for e in EMITTERS)
    # filtered_emitters = filter(kv -> kv[2] != (0, 0), Emitters_modelled)
    Emitters_modelled_names = [Emitters[Emitters[:,"Emitter_id"] .==k, "Product_route_name"][1] for (k, v) in zip(keys(Emitters_modelled),Emitters_modelled)]
    counts_modelled = Dict(p => count(==(p), Emitters_modelled_names) for p in Product_names)
    Emitters_captured = Dict(e => Emitters_modelled[e] for e in EMITTERS if cc_emitter[e] != 0)
    Emitters_cancelled = Dict(e => Emitters_modelled[e] for e in EMITTERS if(cc_emitter[e] == 0) &(TOT_capture_1_CO2[e] != 0))
    Emitters_cancelled_names = [Emitters[Emitters[:,"Emitter_id"] .==k, "Product_route_name"][1] for (k, v) in zip(keys(Emitters_cancelled),Emitters_cancelled)]
    counts_cancelled = Dict(p => count(==(p), Emitters_cancelled_names) for p in Product_names)
    counts_remained = Dict(p => counts_modelled[p] - counts_cancelled[p]  for p in Product_names)
    string_count = Dict(p => "$(counts_remained[p])/$(counts_modelled[p])"  for p in Product_names)
    Emitters_noCC = Dict(e => Emitters_modelled[e] for e in EMITTERS if(cc_emitter[e] == 0) &(TOT_capture_1_CO2[e] == 0))
    Emitters_noCC_name = [Emitters[Emitters[:,"Emitter_id"] .==k, "Product_route_name"][1] for (k, v) in zip(keys(Emitters_noCC),Emitters_noCC)]
    Emitter_names_noCC = unique(Emitters_noCC_name)

    fig = Plots.plot(ylabel = "Production costs [EUR/tpa]")
    groupedbar!(repeat(xvector, 4), ydata,
    group=repeat(Cost_labels, inner=length(Product_names) * 2),  # Group by cost component
    bar_position = :stack,
    xrotation = 90, 
    xticks=(1.5:3:xvector[end], Product_names), 
    bar_width = 0.9,
    xtickfont=font(14), ytickfont=font(14)
    )
    Plots.scatter!(xvector, Totex_routes, markershape = :xcross, label = "TOTEX")
    
    nr = 0 

    # Plots.plot!(twinx(fig), label=false, xticks = false)
    for x in xvector 
        nr = nr +1 
        annotate!(x,- 100 , Plots.text(routes[nr], 10, :black, :right, rotation= 90)) # Totex_routes[nr] + 200
    end 
    nr = 0 
    for x in xvector_1
        nr = nr +1 
        if !(Product_names[nr] in Emitter_names_noCC)
            annotate!(x, - 50 , Plots.text(counts_remained[Product_names[nr]], 10, :black, :center, rotation= 0)) # Totex_routes[nr] + 200
            annotate!(x + 1, - 50 , Plots.text(counts_cancelled[Product_names[nr]], 10, :black, :center, rotation= 0))
        else 
            annotate!(x + 1, - 50 , Plots.text(counts_remained[Product_names[nr]], 10, :black, :center, rotation= 0))
        end
    end 

    Plots.plot!(fig, size= (1000, 600), guidefont = 14, ylim = (-600, 1300), legendfont = 14, legend = :topright)
    Plots.plot!(twiny(fig), label=false, xticks = false)
    Plots.plot!(twinx(fig), label=false, yticks = false)

    display(fig)



    filename_string_2 = "./Figures/Cost_split_$(Scenario_name)_$(CO2_tax).svg"           
    savefig(fig, filename_string_2)




return 
end 


function product_plots(All_industry_results_df)
    Product_names = sort!(unique(Emitters[:, "Product_route_name"]))  
    Base_horizon  = 2050

    # percentage of connection 


    # production costs 

    DF_product_costs = DataFrame()
    DF_avgTandS_costs = DataFrame()
    DF_baseline_co2_costs = DataFrame()
    DF_percentages = DataFrame()
    DF_percentages_1 = DataFrame()
    # DF_product_costs[:, "Scenario_name"] = All_industry_results_df[!, "Scenario_name"]
    for PN in Product_names
        # column_name_add = "Rel_avg_prod_cost_$(PN)"

        # Base_value = (All_industry_results_df[(All_industry_results_df[:, "Scenario_name"] .== Base_scenario) .& (All_industry_results_df[:, "Scenario_horizon"] .== Base_horizon), "Avg_prod_cost_$(PN)"][1])
        # All_industry_results_df[:, column_name_add] = [try (All_industry_results_df[i, "Avg_prod_cost_$(PN)"][1] )./abs(Base_value) catch missing end for i in 1:size(All_industry_results_df,1)]
        # All_industry_results_df[!, "Avg_prod_cost_$(PN)"] = coalesce.(All_industry_results_df[!, "Avg_prod_cost_$(PN)"], 0)
        # All_industry_results_df[!, "Avg_TandS_costs_cc_$(PN)"] = coalesce.(All_industry_results_df[!, "Avg_TandS_costs_cc_$(PN)"], 0)
        # All_industry_results_df[!, "Baseline_co2_cost_$(PN)"] = coalesce.(All_industry_results_df[!, "Baseline_co2_cost_$(PN)"], 0)
        # All_industry_results_df[row, "Percentage_connect_$(PN)"]  = coalesce.(All_industry_results_df[!, "Percentage_connect_$(PN)"], 0)


        for i in 1:length(All_industry_results_df[!, "Avg_prod_cost_$(PN)"])
            if All_industry_results_df[i, "Avg_prod_cost_$(PN)"] == "NaN" # Check for NaN
                global All_industry_results_df[i, "Avg_prod_cost_$(PN)"] = 0.0   # Replace with 0
            end
        end
        for i in 1:length(All_industry_results_df[!, "Avg_TandS_costs_cc_$(PN)"])
            if All_industry_results_df[i, "Avg_TandS_costs_cc_$(PN)"] == "NaN" # Check for NaN
                global All_industry_results_df[i, "Avg_TandS_costs_cc_$(PN)"] = 0.0   # Replace with 0
            end
        end
        for i in 1:length(All_industry_results_df[!, "Baseline_co2_cost_$(PN)"])
            if All_industry_results_df[i, "Baseline_co2_cost_$(PN)"] == "NaN" # Check for NaN
                global All_industry_results_df[i, "Baseline_co2_cost_$(PN)"] = 0.0   # Replace with 0
            end
        end
        for i in 1:length(All_industry_results_df[!, "Percentage_connect_$(PN)"])
            if isnan(All_industry_results_df[i, "Percentage_connect_$(PN)"])# Check for NaN
                All_industry_results_df[i, "Percentage_connect_$(PN)"] = 0.0   # Replace with 0
            end
        end

        for i in 1:length(All_industry_results_df[!, "Percentage_connect_of_1_$(PN)"])
            if isnan(All_industry_results_df[i, "Percentage_connect_of_1_$(PN)"])# Check for NaN
                All_industry_results_df[i, "Percentage_connect_of_1_$(PN)"] = 0.0   # Replace with 0
            end
        end

              # Convert x-values to categorical to handle them as discrete data
        DF_product_costs[:, "Avg_prod_cost_$(PN)"] = All_industry_results_df[!, "Avg_prod_cost_$(PN)"]
        DF_avgTandS_costs[:, "Avg_TandS_costs_cc_$(PN)"] = All_industry_results_df[!, "Avg_TandS_costs_cc_$(PN)"]
        DF_baseline_co2_costs[:, "Baseline_co2_cost_$(PN)"] = All_industry_results_df[!, "Baseline_co2_cost_$(PN)"]
        DF_percentages[:, "Percentage_connect_$(PN)"] = All_industry_results_df[!, "Percentage_connect_$(PN)"]
        DF_percentages_1[:, "Percentage_connect_of_1_$(PN)"] = All_industry_results_df[!, "Percentage_connect_of_1_$(PN)"]

    end



    # Plot connections 

    fig = Plots.plot(ylimit = (-0.1, 1.1), ylabel = "Connection %")
    base_pattern = [2, 2.5, 3, 3.5] # length of the scenario 
    x_numbers = generate_sequence(length(Product_names), base_pattern)
    scenario_colors = ["blue", "red", "green", "orange"]
    scenario_plot_names = ["CDR credits", "No CDR", "Biomass restricted", "Industry exit"]
    flattend_df_percentage = [x for row in eachrow(DF_percentages) for x in row]
    flattend_df_percentage_1 = [x for row in eachrow(DF_percentages_1) for x in row]
    Names_x = names(DF_percentages)

    Plots.scatter!(x_numbers, flattend_df_percentage, xticks = (x_numbers[2:4:end], Product_names), xrotation = 90, color = repeat(scenario_colors, length(Product_names)),  foreground_color_legend= nothing, label = nothing, ms = 6)
    Plots.scatter!(x_numbers, flattend_df_percentage_1, xticks = (x_numbers[2:4:end], Product_names), xrotation = 90, marker = :xcross, color = :black, alpha= 1,  foreground_color_legend= nothing, label = " Max. connection %", legend=(0.05, 0.3), ms = 6)
    for (i, color) in enumerate(scenario_colors)
        Plots.scatter!(twiny(fig), [-0.5], [1.5], label=scenario_plot_names[i], marker=:circle, color=color, xticks = false,  foreground_color_legend= nothing, legend = (0.75, 0.6-i*0.075))  # Add legend item
    end
    intermediate_x_numbers = generate_sequence((length(Product_names)+1), [1.25])
    for i in intermediate_x_numbers
        Plots.plot!([i, i],[-0.2, 1.2], label = false, color = :black, ls = :dash, alpha = 0.5)
    end 
    Plots.plot!([1.25, intermediate_x_numbers[end]],[0, 0], label = false, color = :black, ls = :dash, alpha = 0.5)
    Plots.plot!([1.25, intermediate_x_numbers[end]],[1, 1], label = false, color = :black, ls = :dash, alpha = 0.5)
    # Plots.plot!(twiny(fig),  xticks=false)
    Plots.scatter!(twinx(fig), [-0.5], [1.5],  yticks=false, legend=(0.05, 0.375), label = " Resulting connections %", marker = :circle, color =:black,  foreground_color_legend= nothing)
    Plots.plot!(ylimit = (-0.1, 1.1), xlimit = (1.25,  intermediate_x_numbers[end]), size= (800, 500), xtickfont = font(15), ytickfont = font(15), legendfont = font(15), yguidefont = font(20))
    display(fig)


    filename_string = "./Figures/connections_$(CO2_tax).svg"           
    savefig(fig, filename_string)

    # Plot production costs 

    fig = Plots.plot(ylabel = "Production costs [EUR/tpa]")
    flattend_df_product = [x for row in eachrow(DF_product_costs) for x in row]
    groupedbar!(repeat(Product_names, size(All_industry_results_df[!, 1],1)),  # x-values: product name repeated
    flattend_df_product,     # y-values: relative costs
    group = repeat(scenario_plot_names, inner=length(Product_names)), color = repeat(scenario_colors, inner =length(Product_names)),  xticks=(0.5:length(Product_names), Product_names), xtickfont=font(10), xrotation = 90
    )

    flattend_df_avgTandS = [x for row in eachrow(DF_avgTandS_costs) for x in row]
    groupedbar!(repeat(Product_names, size(All_industry_results_df[!, 1],1)),  # x-values: product name repeated
    flattend_df_avgTandS,     # y-values: relative costs
    group = repeat(scenario_plot_names, inner=length(Product_names)),  xticks=(0.5:length(Product_names), Product_names), xtickfont=font(10),
    labels = false, color = :black, alpha = 0.5, xrotation= 90
    )
    flattend_df_base_co2 =  [x for x in DF_baseline_co2_costs[1,:]]
    Plots.scatter!(0.5:length(Product_names), flattend_df_base_co2, label = false, marker = :xcross, color = :black)
    Plots.scatter!(twinx(fig), [0 0], [-1000 -1000], yticks=false, marker = [:xcross :rect], color = [:black, :black], alpha = 0.5, label = ["Cost of baseline emissions" "Avg. costs of T&S"], legend = :bottomleft)
    Plots.plot!(twiny(fig),  xticks=false)
    Plots.plot!(fig, ylimit= (-800, 1500), size=(800, 500), xtickfont=font(15), ytickfont = font(15), legendfont = font(15), guidefont = font(15),  xrotation = 90)
    display(fig)
    filename_string_2 = "./Figures/products_$(CO2_tax).svg"           
    savefig(fig, filename_string_2)

end

function Sankey_CDR()
    # Dummy data: transitions from scenario 1 to scenario 2
    categories = ["fossil+CC", "fossil no CC", "bio+CC", "bio no CC", "other"]
    transitions = [
        (1, 2, 5),  # 5 emitters from "fossil+CC" to "fossil no CC"
        (1, 3, 3),  # 3 emitters from "fossil+CC" to "bio+CC"
        (2, 4, 4),  # 4 emitters from "fossil no CC" to "bio no CC"
        (3, 5, 2),  # 2 emitters from "bio+CC" to "other"
        (4, 1, 1)   # 1 emitter from "bio no CC" to "fossil+CC"
    ]

    src = [1, 1, 1, 1, 2, 2, 2, 3, 4, 5]
dst = [6, 3, 7, 4, 3, 7, 4, 7, 8, 8]
weights = [0.1, 0.3, 0.5, 0.5, 0.2, 2.8, 1, 0.45, 4.5, 3.3]

sankey(src, dst, weights)

    # Create the Sankey plot
    sankey(categories, transitions, orientation=:horizontal)

    return 

end 


function total_costs_plot(All_key_results_df, Scenario_name_vect, Scenario_horizon_vect)


    flattend_df = vcat(All_key_results_df[:,"Average T&S costs"], All_key_results_df[:,"Total costs"])
    for horizon in Scenario_horizon_vect
        fig = Plots.plot()
        Scenarios = ["$(Scenario_name_vect[i])" for i in 1:length(Scenario_name_vect)]
        groupedbar!(repeat(Scenarios, 2),  # x-values: scenario name repeated
        flattend_df,     # y-values: relative costs
        group = repeat(["Average T&S costs [EUR/tCO2]", "Total system costs [EUR/tCO2Reducedpa]"], inner=length(Scenarios)), 
        )
        Plots.plot!(fig, ylimit= (0, 1500), xlabel= "Scenario", ylabel = "Costs")
        display(fig)
    end


end


function ETS_mass_effect(results_stats_file_HPC, Scenario_name_vect, Scenario_horizon_vect, CO2_tax_vect)

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

    Column_name_vect = ["CO2 tax", "Max total connections", "Optimised connections", "Total capture volume", "Total capture volume fossil", "Total capture volume bio"]
    scenario_colors = ["blue", "red", "green", "orange"]
    #CN = "Optimised connections" #"Total capture volume"
    for SN in Scenario_name_vect
        for SH in Scenario_horizon_vect
            Figure_name_sens = "sens_$(SN)_$(SH)"
            SNV = [SN]
            SHV = [SH]
            Sensitivity_results = DataFrame(collect(Symbol.(names(All_key_results_df))) .=> [[] for _ in names(All_key_results_df)])
            for CO2_tax in CO2_tax_vect
                scenario_key = HPC_result_extraction(results_pipes_file_HPC::String, results_stats_file_HPC::String, results_industry_file_HPC::String, SNV, SHV, CO2_tax, (plotting = false; plotting))
                Sensitivity_results =vcat(Sensitivity_results,scenario_key)
                
                # Plots.scatter!(fill(CO2_tax, length(All_key_results_df[!,1])), All_key_results_df[!, CN], color = scenario_colors)
                # print(All_key_results_df[!, "Max total connections"])

            end
            print(Sensitivity_results[:,  "MIPgap"]) 
            fig = Plots.plot()
            groupedbar!(
            CO2_tax_vect,               # x-axis (CO2 tax)
            [Sensitivity_results."Total capture volume bio" Sensitivity_results."Total capture volume fossil"],  # Stacked values
            label=["Bio" "Fossil"],     # Labels for legend
            bar_position = :stack,
            ylabel=L"Capture Volume [MtCO$_2$pa]",
            color=["palegreen3" "lightcyan3"],  # Optional: custom colors for bars
            foreground_color_legend = nothing, 
            bar_width=20,  # Adjust bar width
            ylim = (0, 300), 
            legend = (0.1, 0.95),
            xticks = (CO2_tax_vect),
            xlabel= L"Carbon price [EUR/tCO$_2$]"          
            )
            Plots.plot!(twinx(fig),
                CO2_tax_vect,                # x-axis
                Sensitivity_results."Optimised connections", # y-axis (right)
                seriestype=:line,
                label="Optimised Connections",
                color=:black,
                lw=2,
                ylim=(0, 300),
                markershape=:circle,
                markerstrokecolor=:black,
                yaxis=:right,
                foreground_color_legend = nothing, 
                legend = (0.6, 0.89)
            )
            Plots.plot!(twinx(fig),
                CO2_tax_vect,                # x-axis
                Sensitivity_results."Max total connections", # y-axis (right)
                seriestype=:line,
                label="Max connections",
                color=:black,
                lw=2,
                ylim=(0, 300),
                markershape=:circle,
                markerstrokecolor=:black,
                linestyle=:dash,
                yaxis=:right,               # Use right y-axis
                ylabel="Number of connections",
                foreground_color_legend = nothing, 
                legend = (0.6, 0.95)
            )
            Plots.plot!(twinx(fig),
                CO2_tax_vect,   ymirror = true,              # x-axis
                Sensitivity_results."Average T&S costs", # y-axis (right)
                seriestype=:line,
                label="Avg. T&S costs [EUR/tCO2]",
                color=:grey,
                lw=2,
                ylim=(0, 150),
                markershape=:xcross,
                markerstrokecolor=:grey,
                linestyle=:dash,
                yaxis=:right,               # Use right y-axis
                ylabel="Average T&S costs",
                foreground_color_legend = nothing, 
                legend = (0.6, 0.85)
            )

            filename_string = "./Figures/$(Figure_name_sens)_$(detail_level).svg"
            Plots.plot!(twiny(fig), label=false, xticks = false)

            Plots.plot!(fig, size=(800, 500), xtickfontsize = 18, ytickfont = font(18), legendfont = font(18), guidefontsize = 18)
            Plots.savefig(fig, filename_string)
            display(fig)
        end
    end



end


function WtP_curve(Scenario_name)

Emitters = import_data_industry(CO2_tax::Any, Scenario_name::String, Scenario_horizon::Int64) #, (load_data=true; load_data))

include("parameters.jl")    # run all the parameters of the script

Key_results_df =  key_results_extract(results_stats_file::String, Scenario_name::String, Region::String,  CO2_tax::Int64)
TaS = Key_results_df[Key_results_df[:, "Parameters"] .== "Average T&S costs", "Values"][1]
file_industry = "./Output data files/CSV intermediaries $(detail_level)/Results_industry_HPC_$(Scenario_name)_$(Region)_$(CO2_tax).csv"
Industry_connection_results = CSV.read(file_industry, DataFrame)
cc_emitter =  Dict(e => try Industry_connection_results[Industry_connection_results[:, "Emitters"] .== e, "Bin_connection"][1] catch skip end for e in EMITTERS)
    

WtP =  Dict(emitter => (CAPEX_noCC[emitter] + OPEX_noCC[emitter] - CAPEX_1[emitter] - OPEX_1[emitter])./((TOT_bio_CO2[emitter]+TOT_fossil_CO2[emitter])) for emitter in EMITTERS) # EUR/tCO2
Emitters.WtP = [get(WtP, id, NaN) for id in Emitters.Emitter_id]  # Assuming column "Emitter_ID"

# Remove rows with missing WtP or CO2 capture
Emitters_select = dropmissing(Emitters, [:WtP, :Captured_CO2_1_tCO2ptpa])
Emitters_select = Emitters_select[.!isnan.(Emitters_select.WtP), :]
# Sort emitters by WtP
sorted_emitters = sort(Emitters_select, [:WtP, :Product_route_name], rev=true) # from high to low willingness and on product route name (if same WtP)
sorted_emitters = sorted_emitters[.!iszero.(sorted_emitters.Captured_CO2_1_tCO2ptpa), :]
# Prepare data for MACC-style plot
sorted_emitters.widths = sorted_emitters.Captured_CO2_1_tCO2ptpa .* sorted_emitters.Product_cap_ktpa / 1000 #MtCO2 captured per year per emitter

# Emitters_glass = Emitters_select[Emitters_select[:, "Sector_name"] .== "Glass", :]
# GLASS_ID = Emitters_select[Emitters_select[:, "Sector_name"] .== "Glass", "Emitter_id"]
# [cc_emitter[e] for e in GLASS_ID]
# Emitters_glass.widths = Emitters_glass.Captured_CO2_1_tCO2ptpa .* Emitters_glass.Product_cap_ktpa / 1000
# Cumulative x-starts of the bars
sorted_emitters.x_start = round.(cumsum(vcat(0.0, sorted_emitters.widths[1:end-1])), digits=6)


# annotations
    Product_names = sort!(unique(Emitters[:, "Product_route_name"]))  
    Emitters_modelled = Dict(e =>  (Emitters[Emitters[:,"Emitter_id"] .==e, "Lon"][1],  Emitters[Emitters[:,"Emitter_id"] .==e, "Lat"][1]) for e in EMITTERS)
    # filtered_emitters = filter(kv -> kv[2] != (0, 0), Emitters_modelled)
    Emitters_modelled_names = [Emitters[Emitters[:,"Emitter_id"] .==k, "Product_route_name"][1] for (k, v) in zip(keys(Emitters_modelled),Emitters_modelled)]
    counts_modelled = Dict(p => count(==(p), Emitters_modelled_names) for p in Product_names)
    Emitters_captured = Dict(e => Emitters_modelled[e] for e in EMITTERS if cc_emitter[e] != 0)
    Emitters_cancelled = Dict(e => Emitters_modelled[e] for e in EMITTERS if(cc_emitter[e] == 0) &(TOT_capture_1_CO2[e] != 0))
    Emitters_cancelled_names = [Emitters[Emitters[:,"Emitter_id"] .==k, "Product_route_name"][1] for (k, v) in zip(keys(Emitters_cancelled),Emitters_cancelled)]
    counts_cancelled = Dict(p => count(==(p), Emitters_cancelled_names) for p in Product_names)
    counts_remained = Dict(p => counts_modelled[p] - counts_cancelled[p]  for p in Product_names)
    string_count = Dict(p => "$(counts_cancelled[p])/$(counts_modelled[p])"  for p in Product_names)


# Plot


# Group by Product Route
gdf = DataFrames.groupby(sorted_emitters, :Product_route_name)

# 3. Order product groups by first appearance (cumulative order)
# ordered_products = unique(sorted_emitters.Product_route_name)

ordered_products = reverse([
    "fertiliser-nitric-acid",
    "fertiliser-urea",
    "fertiliser-ammonia",
    "chemical-olefins",
    "chemical-PEA",
    "chemical-PE",
    "cement",
    "steel-primary",
    "refineries-light-liquid-fuel",
    "glass-container",
    "glass-float",
    "glass-fibre"

])

# Generate color palette with same length
product_colors = Dict(
    ordered_products .=> palette(:tab10, length(ordered_products))
)


# 4. Assign a color per product type (in order of appearance)
colors = Dict(ordered_products .=> palette(:tab10, length(ordered_products)))

# Initialize plot
p = Plots.plot(; legend=true,
          xlabel="Cummulative capture volume per emitter (MtCO2pa)",
          ylabel="Willingness to pay for T\\&S (EUR/tCO2)",
          size=(700, 500),
          tickfont=font(14), guidefont=font(14), legendfont=font(14), ylim = (0,320))
seen_labels = Set{String}()
# Plot each product group
    for product in ordered_products
        try 
            sorted_emitters_product = sorted_emitters[sorted_emitters[:, "Product_route_name"] .== product, :]
            for row in eachrow(sorted_emitters_product)
                product = row.Product_route_name
                label = product ∉ seen_labels ? "$(product) (x: $(string_count[product]))" : ""
                push!(seen_labels, product)
                Plots.bar!(p, [row.x_start .+ row.widths/2], [row.WtP];
                    bar_width = row.widths,
                    fillalpha = 0.2,
                    linecolor = product_colors[product],
                    fillcolor = product_colors[product],
                    linealpha = 1.0,
                    label = label, #label
                    legend = :topright #:topleft
                )
                if cc_emitter[row.Emitter_id] < 0.1
                    # Plots.annotate!([row.x_start .+ row.widths/2], [row.WtP .+ 6] , Plots.text("x", 15, :darkred)) 
                    Plots.scatter!(twinx(p), [row.x_start .+ row.widths/2], [row.WtP .+ 6] , ylim=(0,320), yticks = false, xticks = false, marker=(:xcross, 5, :darkred), label="Cancelled sites", legend = :topleft, legendfont=font(14))
                end
            end
        catch e 
            missing 
        end
end
# Hide ticks and labels
# Plot average price


Plots.hline!([TaS], label="Avg. T\\&S costs", color=:black, linestyle=:dash)
# creating a scattered marker
# Plots.scatter!(twinx(p), [0], [0], ylim=(0,320), yticks = false, xticks = false, marker=(:xcross, 5, :darkred), label="Cancelled sites", legend = :topright)
Plots.plot!(twiny(p), label=false, xticks = false, legend = :topright, legendfont=font(14))
Plots.plot!(twinx(p), label=false, yticks = false, legend = :topright, legendfont=font(14))



display(p)

# for (i, group) in enumerate(gdf)
#     for (j, row) in enumerate(eachrow(group))
#         Plots.bar!(p, [row.x_start .+ row.widths/2], [row.WtP];
#              bar_width = row.widths,
#              fillalpha=0.5,
#              linecolor=colors[i],
#              fillcolor=colors[i],
#              linealpha=1.0,
#              label=(j == 1 ? group.Product_route_name[1] : "")  # ✅ only first gets label
#         )
#     end
# end

filename_string = "./Figures/Base/WtP_$(Scenario_name).svg"
Plots.savefig(p, filename_string)



end

