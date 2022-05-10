namespace ItemFinder 
{
	uint num_items = 4;
	uint col_size = 2;
	uint num_col = num_items / col_size;

	ItemFinderInterface@ g_interface;
	
	[Hook]
	void GameModeStart(Campaign@ campaign, SValue@ save) {
		campaign.m_userWindows.insertLast(@g_interface = ItemFinderInterface(campaign.m_guiBuilder));
	}

	[Hook]
	void GameModeUpdate(Campaign@ campaign, int dt, GameInput& gameInput, MenuInput& menuInput)	{
		if (g_interface is null)
			return;

		if (Platform::GetKeyState(62).Pressed) // F5
			campaign.ToggleUserWindow(g_interface);
	}
	
	array<ActorItem@> g_pickedItems(num_items);
	array<uint> pickedItemsList(num_items);
	array<string> defaultText = { "Item 1", "Item 1 alternative", "Item 2", "Item 2 alternative" };

		// TODO:

		// check town level to see what is craftable

		// make a 3rd column, and make them rows instead

		// check inventory for crafted item when opening interface

		// only work in town..

		// add item icon!
		// Widget@ AddItem(Widget@ template, Widget@ list, Upgrades::Upgrade@ upgrade) override
		// {
		// 	auto wNewItem = UpgradeShopMenuContent::AddItem(template, list, upgrade);

		// 	auto itemUpgrade = cast<Upgrades::ItemUpgrade>(upgrade);
		// 	if (itemUpgrade !is null)
		// 	{
		// 		auto wIconContainer = cast<RectWidget>(wNewItem.GetWidgetById("icon-container"));
		// 		if (wIconContainer !is null && itemUpgrade.m_item.quality != ActorItemQuality::Common)
		// 			wIconContainer.m_color = GetItemQualityBackgroundColor(itemUpgrade.m_item.quality);

		// 		auto wIcon = cast<UpgradeIconWidget>(wNewItem.GetWidgetById("icon"));
		// 		if (wIcon !is null)
		// 			wIcon.Set(itemUpgrade.m_step);
		// 	}	
	
	class ItemFinderInterface : UserWindow
	{
		array<ScalableSpriteButtonWidget@> m_wItemButton(num_items);
		array<TextWidget@> m_wItemText(num_items);

		Widget@ m_wPopup = m_widget.GetWidgetById("popup-parent");
		ScrollableWidget@ m_wScrollableList = cast<ScrollableWidget>(m_widget.GetWidgetById("scrollable-list"));
		ScalableSpriteButtonWidget@ m_wClearButton = cast<ScalableSpriteButtonWidget>(m_widget.GetWidgetById("clearitems"));
		Widget@ m_wItemTemplate = m_widget.GetWidgetById("item-template");
		array<Widget@> m_wItems;
		array<ActorItem@> g_allItems;

		int curr_btn;
		int curr_col;
		array<bool> rare_in_col(num_col);
		bool show_rares = true;
		bool show_popup = false;
		

		ItemFinderInterface(GUIBuilder@ b)
		{
			super(b, "gui/reroller.gui");
			for (uint i = 0; i < num_items; i++) {
				@m_wItemButton[i] = cast<ScalableSpriteButtonWidget>(m_widget.GetWidgetById("item" + i));
				@m_wItemText[i] = cast<TextWidget>(m_widget.GetWidgetById("picked" + i));
			}
			InitializeItems();
			BuildNewPopup();
		}

		void InitializeItems()
		{
			// add support for checking item shop level and limit items accordingly
			for (uint i = 0; i < g_items.m_allItemsList.length(); i++) {
				auto item = g_items.m_allItemsList[i];
				auto record = GetLocalPlayerRecord();
				if (!item.inUse && item.quality != ActorItemQuality::Epic && item.quality != ActorItemQuality::Legendary ) {
					if (item.requiredNgp != "" && (record is null || record.ngps[item.requiredNgp] == 0))
						continue;

					if (item.requiredFlag != "" && !g_flags.IsSet(item.requiredFlag))
						continue;

					if (item.blockedFlag != "" && g_flags.IsSet(item.blockedFlag))
						continue;

					if (!HasDLC(item.dlc))
						continue;

					g_allItems.insertLast(g_items.m_allItemsList[i]);
				}
			}
			g_allItems.sort(function(a, b){
				if(a.quality == b.quality)
					return Resources::GetString(a.name) < Resources::GetString(b.name);
				return a.quality > b.quality;
			});
		}

		void BuildNewPopup()
		{
			m_wItems.resize(g_allItems.length());
			for (uint i = 0; i < m_wItems.length(); i++) {
				ActorItem@ item = g_allItems[i];
				@m_wItems[i] = m_wItemTemplate.Clone();
				ButtonWidget@ itemContainer = cast<ButtonWidget>(m_wItems[i].m_children[0]);
				TextWidget@ itemName = cast<TextWidget>(itemContainer.m_children[0]);

				m_wItems[i].m_visible = true;

				if (item.quality != ActorItemQuality::Common)
					itemContainer.m_color = desaturate(GetItemQualityColor(item.quality));

				itemName.SetText(Resources::GetString(item.name));
				itemName.SetColor(GetItemQualityColor(item.quality));

				itemName.m_tooltipTitle = "\\c" + GetItemQualityColorString(item.quality) + utf8string(Resources::GetString(item.name)).toUpper().plain();
				itemName.m_tooltipText = Resources::GetString(item.desc);

				if (item.set !is null) {
					itemName.m_tooltipText += "\n\n" + GetItemSetColorString(GetLocalPlayerRecord(), item);
				}
				itemContainer.m_func = i + " " + item.id;
				m_wScrollableList.AddChild(m_wItems[i]);
			}
		}

		void OnFunc(Widget@ sender, string name) override
		{
			BaseGameMode@ gm = cast<BaseGameMode>(g_gameMode);
			auto buttonName = name.split("item-button");
			if (buttonName.length() > 1) {
				curr_btn = parseInt(buttonName[1]);
				curr_col = curr_btn / col_size;
				PopupVisible(!show_popup);
			}
			else if (name == "close")
				gm.ToggleUserWindow(g_interface);
			else if (name == "clearitems")
				ClearItems();
			else {
				auto parse = name.split(" ");
				uint itemIndex = parseInt(parse[0]);
				ActorItem@ item = g_items.GetItem(parse[1]);
				if (item.quality == ActorItemQuality::Rare)
					rare_in_col[curr_col] = true;

				ClickedItem(item, itemIndex);
				if (gm !is null)
					gm.m_tooltip.Hide();

				@g_pickedItems[curr_btn] = item;
			}
		}

		void ClickedItem(ActorItem@ item, int item_index)
		{
			m_wItems[item_index].m_visible = false; // makes the clicked item invisible in list

			if (m_wItemText[curr_btn].m_str != defaultText[curr_btn]) { // if an item was previously picked
				int item_old = pickedItemsList[curr_btn]; // find the index of the item previously assigned to curr_btn
				m_wItems[item_old].m_visible = true; // make the old item visible in list again
			}

			if (item.quality == ActorItemQuality::Rare) // check if item is rare
				rare_in_col[curr_col] = true; // specify that a rare has been picked for this column

			pickedItemsList[curr_btn] = item_index; // store the index of the item in picked items
			m_wItemText[curr_btn].SetText(Resources::GetString(item.name)); // set the name of the text field
			PopupVisible(false);
		}
		
		void SetTextWidget(string id, string text, bool setColor = false)
		{
			auto w = cast<TextWidget>(m_widget.GetWidgetById(id));
			if (w is null)
				return;
			w.SetText(text, setColor);
		}

		void PopupVisible(bool display)
		{
			// check here if an item has been crafted, and if so, make it invisible
			if (display) {
				CheckHideRares();
				m_wPopup.m_visible = true;

				switch( curr_col ) {
					case 0:
						m_wPopup.m_offset.x = -93;
						break;
					case 1:
						m_wPopup.m_offset.x = 122;
				}
				ButtonsEnabled(false);
				show_popup = true;
			}
			else {
				m_wPopup.m_visible = false;
				ButtonsEnabled(true);
				m_wScrollableList.ScrollUp();
				m_wPopup.Unfocus();
				show_popup = false;
			}
		}

		void ButtonsEnabled(bool enable)
		{
			for (uint i = 0; i < m_wItemButton.length(); i++) {
				if(i != curr_btn)
					m_wItemButton[i].m_enabled = enable;
			}
			m_wClearButton.m_enabled = enable;
		}

		
		void CheckHideRares()
		{
			for (uint i = 0; i < num_col; i++) {
				if(show_rares && rare_in_col[i] && i != curr_col) {
					AllRaresVisible(false);
				}
				else if (!show_rares && rare_in_col[i] && i == curr_col) {
					AllRaresVisible(true);
					SelectedItemsVisible(false);
				}
			}
		}

		void AllRaresVisible(bool display)
		{
			for (uint i = 0; i < g_allItems.length(); i++) {
				if(g_allItems[i].quality == ActorItemQuality::Rare) {
					m_wItems[i].m_visible = display;
				}
				else {
					show_rares = display;
					break;
				}
			}
		}

		void SelectedItemsVisible(bool display)
		{
			for(uint i = 0; i < pickedItemsList.length(); i++) {
				int index = pickedItemsList[i];
				m_wItems[index].m_visible = display;
			}
		}

		void ClearItems()
		{
			SelectedItemsVisible(true);
			AllRaresVisible(true);
			ButtonsEnabled(true);
			
			for (uint i = 0; i < num_items; i++) {
				m_wItemText[i].SetText(defaultText[i]);
			}

			pickedItemsList.resize(0);
			pickedItemsList.resize(num_items);

			g_pickedItems.resize(0);
			g_pickedItems.resize(num_items);

			rare_in_col.resize(0);
			rare_in_col.resize(num_col);
		}
	}

	// Changes:

	// Fixed bug where the popups would only show up every other time you opened the interface

	// Removed the lingering print() that printed ~2000x "true" in console on loading profile with mod enabled

	// Now hiding all items that are not possible to get in the shop

	// Added ability to select alternatives to your items

	// Improved speed

	// NOTE: Bug where UI sometimes breaks during reroll still happens...


}

