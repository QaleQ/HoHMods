class GeneralStoreMenuContent : UpgradeShopMenuContent
{
	Widget@ m_wRerollTemplate;
	Widget@ m_wReroll;

	Upgrades::ItemShop@ m_itemShop;

	GeneralStoreMenuContent(ShopMenu@ shopMenu)
	{
		super(shopMenu, "generalstore");

		@m_itemShop = cast<Upgrades::ItemShop>(m_currentShop);
		if (m_itemShop is null)
			PrintError("\"generalstore\" is not an item shop!");
	}

	int GetRerollCost()
	{
		return 100;
	}

	string GetGuiFilename() override
	{
		return "gui/shop/generalstore.gui";
	}

	void OnShow() override
	{
		@m_wRerollTemplate = m_widget.GetWidgetById("reroll");

		UpgradeShopMenuContent::OnShow();
	}

	Widget@ AddItem(Widget@ template, Widget@ list, Upgrades::Upgrade@ upgrade) override
	{
		auto wNewItem = UpgradeShopMenuContent::AddItem(template, list, upgrade);

		auto itemUpgrade = cast<Upgrades::ItemUpgrade>(upgrade);
		if (itemUpgrade !is null)
		{
			auto wIconContainer = cast<RectWidget>(wNewItem.GetWidgetById("icon-container"));
			if (wIconContainer !is null && itemUpgrade.m_item.quality != ActorItemQuality::Common)
				wIconContainer.m_color = GetItemQualityBackgroundColor(itemUpgrade.m_item.quality);

			auto wIcon = cast<UpgradeIconWidget>(wNewItem.GetWidgetById("icon"));
			if (wIcon !is null)
				wIcon.Set(itemUpgrade.m_step);
		}

		return wNewItem;
	}

	void ReloadList() override
	{
		if (m_wReroll !is null)
			m_wReroll.RemoveFromParent();

		UpgradeShopMenuContent::ReloadList();

		if (!m_wSoldOut.m_visible)
		{
			@m_wReroll = m_wRerollTemplate.Clone();
			m_wReroll.SetID("");
			m_wReroll.m_visible = true;

			auto wRerollButton = cast<ScalableSpriteIconButtonWidget>(m_wReroll.GetWidgetById("button"));
			if (wRerollButton !is null)
			{
				int cost = GetRerollCost();

				int numItemsNow = int(GetLocalPlayerRecord().generalStoreItems.length());
				int numItemsOriginal = m_itemShop.ItemsForLevel(m_shopMenu.m_currentShopLevel);

				wRerollButton.m_enabled = (Currency::CanAfford(cost) && numItemsNow == numItemsOriginal);
				if (wRerollButton.m_enabled)
					wRerollButton.SetText(Resources::GetString(".shop.generalstore.reroll", { { "cost", cost } }));
				else
					wRerollButton.SetText(Resources::GetString(".shop.generalstore.rerolldisabled"));
			}

			m_wItemList.AddChild(m_wReroll);
		}

		// Ughhhhh
		m_shopMenu.DoLayout();
		m_shopMenu.DoLayout();
	}

	void OnFunc(Widget@ sender, string name) override
	{
		if (name == "reroll")
		{
			int cost = GetRerollCost();
			
			bool foundAll = false;
			int count = 0;
			while(!foundAll && count < 250)
			{
				if (!Currency::CanAfford(cost))
				{
					PrintError("Not enough gold to reroll!");
					return;
				}

				Currency::Spend(cost);

				auto player = GetLocalPlayerRecord();

				auto itemShop = cast<Upgrades::ItemShop>(m_currentShop);
				itemShop.RerollItems(m_shopMenu.m_currentShopLevel, player);

				ReloadList();	
				count++;
				array<bool> valid_col = {false, false};
				array<bool> empty_col = {true, true};
				for (int i = 0; i < ItemFinder::g_pickedItems.length(); i++) {
					ActorItem@ item = @ItemFinder::g_pickedItems[i];
					bool empty = item is null;
					bool valid = !empty && (player.generalStoreItems.find(item.idHash) != -1);
					int col = i / 2;

					empty_col[col] = empty_col[col] && empty;
					valid_col[col] = valid_col[col] || valid;
				}
				foundAll = (empty_col[0] || valid_col[0]) && (empty_col[1] || valid_col[1]);
			}
			print("Rerolled " + count + " times");
		}
		else
			print(name);
			UpgradeShopMenuContent::OnFunc(sender, name);
	}
}
